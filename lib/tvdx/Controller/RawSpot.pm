package tvdx::Controller::RawSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::SQLite;
use DateTime::Format::HTTP;
use LWP::Simple;
use RRDs;
use List::MoreUtils 'none';
use Data::Dumper;

# URL for looking up callsign, location, TSID, etc.
my $RABBITEARS_TVQ = "http://www.rabbitears.info/rawlookup.php?";

BEGIN { extends 'Catalyst::Controller::REST' }

=head1 NAME

tvdx::Controller::RawSpot - Catalyst Controller

=head1 DESCRIPTION

Process Raw spots from clients.  These are spots that contain all the data
the tuner generates, not just stations that are coming in and one virtual
channel.

=head1 METHODS

=cut


=head2 raw_spot

Accept raw spots from client and convert into a data structure Perl can use.

=cut

sub raw_spot :Global :ActionClass('REST') {}

sub raw_spot_POST :Global {
  my ( $self, $c ) = @_;

  # the current time formatted to sqlite format (UTC time zone)
  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $now_epoch = time;

  # json with information from (client) scanlog.pl
  my $json = $c->req->data;

  my ($junk,$tuner_id,$tuner_number) = split /_/, $json->{'user_id'};

  # log if tuner isn't found
  if (! $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id})) {
    open L, ">>/tmp/unknown_tuner" or return 0;
    print L "$sqlite_now: tuner_id $tuner_id not found in tuner table\n";
    close L;
    $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
    $c->response->status(403);
    return;
  }

  RAWSPOT: for my $channel (keys %{$json->{'rf_channel'}}) {
    my $channel_details   = $json->{'rf_channel'}->{$channel};
    my $modulation        = $channel_details->{modulation};
    my $strength          = $channel_details->{strength};
    my $sig_noise         = $channel_details->{sig_noise};
    my $symbol_err        = $channel_details->{symbol_err};
    my $tsid              = $channel_details->{tsid};
    my %virtual           = %{$channel_details->{virtual}};
    my $reporter_callsign = $channel_details->{reporter_callsign};

    # need at least a strength to log
    next RAWSPOT unless $strength;
    # ignore bogus channel numbers
    next RAWSPOT if ($channel !~ /^\d+$/);
    next RAWSPOT if ($channel < 2 || $channel > 69);

    # return callsign or undef if it can't be determined and a virtual
    # channel for legacy column in fcc table
    my ($callsign,$fcc_virtual)
      = $self->_find_call($c,$channel,$channel_details);

    # record signal strength and possibly sig_noise for rrd named channel number
    $self->_rrd_update_nocall($c,$channel,$json);

    # nothing further to log if no decode
    next RAWSPOT unless defined $callsign;

    # add or update virtual channel table
    $self->_virtual_current($c,$callsign,$channel_details);

    # add or update tsid table if needed
    $self->_tsid_current($c,$callsign,$channel_details);

    # update tuner/callsign rrd file and Signal table
    if ( $self->_signal_update(
           $c,$tuner_id,$tuner_number,
           $channel,$callsign,$fcc_virtual,$channel_details) == 0) {
      $c->response->body('FAIL');
      $c->response->status(400);
      return;
    }
  }
  $c->response->body('OK');
  $c->response->status(202);
}


# determine callsign from raw channel information.  Updates (if > 1 day old)
# rabbitears_call, rabbitears_tsid and fcc tables. 
sub _find_call {
  my ($self,$c,$tuner_channel,$channel_details) = @_;

  # nothing to look up if there's no modulation
  if ($channel_details->{modulation} eq 'none') {
    return (undef,undef);
  }

  # the current time formatted to sqlite format (UTC time zone)
  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);

  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  # determine virtual channel for fcc table
  my $fcc_virt = $tuner_channel;  # use channel number if there are no virtuals
  if (%{$channel_details->{virtual}}) {
    # any subchannel will do, just choose a random one
    my ($some_key) = keys %{$channel_details->{virtual}}; 
    if (exists $channel_details->{virtual}{$some_key}{channel}) {
      ($fcc_virt) = split /\./,$channel_details->{virtual}{$some_key}{channel};
    }
  }

  # transmitter power, location, etc.  Order is from rabbitears.info lookup
  # fcc_virt key, value is also in %transimtter
  my %transmitter;
  my @rabbitears_keys = qw(call fcc_channel city state rcamsl erp
      n_or_s lat_deg lat_min lat_sec w_or_e lon_deg lon_min lon_sec
      digital_tsid analog_tsid observed_tsid);

  # try tsid (excepting 0, 1 and greater than 32766) and channel
  if (   $channel_details->{tsid} 
      && $channel_details->{tsid} > 1
      && $channel_details->{tsid} < 32767) {

    # update or create rabbitears_tsid if entry is old or missing
    my ($re_tsid_find) = $c->model('DB::RabbitearsTsid')
                           ->find({'tsid'=>$channel_details->{tsid}});
    my $rlu;
    if (   (! $re_tsid_find)
        || (DateTime::Format::SQLite->parse_datetime(
              $re_tsid_find->last_re_lookup) < $yesterday)) {
      $rlu = get($RABBITEARS_TVQ . "tsid=$channel_details->{tsid}");
      if (defined $rlu) {
        # create or update rabbitears_tsid table
        if (! $re_tsid_find) {
          $c->model('DB::RabbitearsTsid')->create({
             'tsid' => $channel_details->{tsid},
             're_rval' => $rlu,
             'last_re_lookup' => $sqlite_now,});
        }
        else {
          $re_tsid_find->update({'last_re_lookup' => $sqlite_now});
        }
      }
    }
    else {
      $rlu = $re_tsid_find->re_rval;
    }
    if (defined $rlu) {
      foreach my $s (split /\n/, $rlu) {
        my %rlu_values;
        @rlu_values{@rabbitears_keys} = split /\s*\|/,$s;
        if ($tuner_channel == $rlu_values{fcc_channel}) {
          %transmitter = %rlu_values;
          $transmitter{fcc_virt} = $fcc_virt;
          last;
        }
      }
    }
  }

  # else no tsid so try callsign and channel
  else {
    # loop over virtual channels, look for something resembling a callsign
    VIRT_CHAN: for my $program (keys %{$channel_details->{virtual}}) {
      next if $channel_details->{virtual}{$program}{name} !~ /^([CWKX](\d\d)*[A-Z]{2,3})/;
      my $possible_call = uc $1;

      # update or create rabbitears_call if entry is old or missing
      my ($re_call_find) = $c->model('DB::RabbitearCall')
                             ->find({'callsign' => $possible_call});
      my $rlu;
      if (   (! $re_call_find)
          || (DateTime::Format::SQLite->parse_datetime(
                $re_call_find->last_re_lookup) < $yesterday)) {
        $rlu = get($RABBITEARS_TVQ . "call=$possible_call");
        if (defined $rlu) {
          # create or update rabbitears_call table
          if (! $re_call_find) {
            $c->model('DB::RabbitearCall')->create({
               'callsign' => $possible_call,
               're_rval' => $rlu,
               'last_re_lookup' => $sqlite_now,});
          }
          else {
            $re_call_find->update({'last_re_lookup' => $sqlite_now});
          }
        }
      }
      else {
        $rlu = $re_call_find->re_rval;
      }
      if (defined $rlu) {
        foreach my $s (split /\n/, $rlu) {
          my %rlu_values;
          @rlu_values{@rabbitears_keys} = split /\s*\|/,$s;
          if ($tuner_channel == $rlu_values{fcc_channel}) {
            %transmitter = %rlu_values;
            $transmitter{fcc_virt} = $fcc_virt;
            last VIRT_CHAN;
          }
        }
      }
    }
  }

  # transmitter could not be identified if hash was not populated
  return(undef,undef) unless %transmitter;

  # add units to height
  my $rcamsl = "$transmitter{rcamsl} m";
  # add units to power
  my $erp = "$transmitter{erp} kW";
  my $location = "$transmitter{city}, $transmitter{state}";
  my $lat_decimal =    $transmitter{lat_deg}
                     + $transmitter{lat_min}/60
                     + $transmitter{lat_sec}/3600;
  $lat_decimal = -1 * $lat_decimal if $transmitter{n_or_s} eq 'S';
  my $lon_decimal =    $transmitter{lon_deg}
                     + $transmitter{lon_min}/60
                     + $transmitter{lon_sec}/3600;
  $lon_decimal = -1 * $lon_decimal if $transmitter{w_or_e} eq 'W';

  # update fcc table with %transmitter, if needed
  my ($fcc_call) = $c->model('DB::Fcc')
                     ->find({'callsign' => $transmitter{call}});

  # new record if FCC data is missing
  if (! $fcc_call) {
    $c->model('DB::Fcc')->create({
      'callsign'        => $transmitter{call},
      'rf_channel'      => $transmitter{fcc_channel},
      'latitude'        => $lat_decimal,
      'longitude'       => $lon_decimal,
      'start_date'      => $sqlite_now,
      'virtual_channel' => $transmitter{fcc_virt},
      'city_state'      => $location,
      'erp_kw'          => $erp,
      'rcamsl'          => $rcamsl,
      'last_fcc_lookup' => $sqlite_now, });
  }
  # update record if FCC data is old
  if (   $fcc_call
      && DateTime::Format::SQLite
         ->parse_datetime($fcc_call->last_fcc_lookup) < $yesterday) {
    $fcc_call->update({'last_fcc_lookup' => $sqlite_now});
  }

  if (defined $transmitter{call} && defined $transmitter{fcc_virt}) {
    return ($transmitter{call},$transmitter{fcc_virt});
  }
  else {
    return (undef,undef);
  }
}


# create or update rrd for channels with no modulation decoded
sub _rrd_update_nocall {
  my ($self,$c,$channel,$json) = @_;

  my ($junk,$tuner_id,$tuner_number) = split /_/, $json->{'user_id'};
  my $strength = $json->{rf_channel}{$channel}{strength};
  my $sig_noise = $json->{rf_channel}{$channel}{sig_noise};

  my $rrd_file = join '_', ($tuner_id,$tuner_number,$channel);
  $rrd_file = $c->config->{rrd_dir} . "/$rrd_file.rrd";

  if (! -r $rrd_file) {
    RRDs::create( $rrd_file, '--start', '-6hours', '--step', '60',
                  "DS:strength:GAUGE:300:0:100",
                  "DS:sig_noise:GAUGE:300:0:100",
                  "RRA:MAX:.99:1:288000",
                  "RRA:MAX:.99:60:131040" );
  }

  RRDs::update( $rrd_file, '--template', 'strength:sig_noise',
                "N:$strength:$sig_noise");
}


# Update or create virtual table entry for callsign
sub _virtual_current {
  my ($self,$c,$callsign,$channel_details) = @_;

  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  # process each virtual channel
  for my $program (keys %{$channel_details->{virtual}}) {
    my ($v_row) =
      $c->model('DB::Virtual')->find(
        {'callsign' => $callsign,
         'name'     => $channel_details->{virtual}{$program}{name},
         'channel'  => $channel_details->{virtual}{$program}{channel}});

    # all new entry?
    if (!$v_row) {
      $c->model('DB::Virtual')->create({
        'rx_date'  => $sqlite_now,
        'name'     => $channel_details->{virtual}{$program}{name},
        'channel'  => $channel_details->{virtual}{$program}{channel},
        'callsign' => $callsign});
      next;
    }
    # else update existing row
    else {
      $v_row->update({'rx_date'  => $sqlite_now});
    }
  }
}

  
# Update or create tsid table entry for callsign
sub _tsid_current {
  my ($self,$c,$callsign,$channel_details) = @_;

  # nothing to do if tsid is missing or invalid
  unless (   $channel_details->{tsid}
           && $channel_details->{tsid} > 1
           && $channel_details->{tsid} < 32767) { return }

  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );
  my ($tsid_row) = $c->model('DB::Tsid')->find(
        {'callsign' => $callsign,
         'tsid'     => $channel_details->{tsid}});
  # all new entry?
  if (! $tsid_row) {
    $c->model('DB::Tsid')->create({
      'rx_date'  => $sqlite_now,
      'tsid'     => $channel_details->{tsid},
      'callsign' => $callsign});
  }
  # else update existing row
  else {
    $tsid_row->update({'rx_date'  => $sqlite_now});
  }
}


# update signal table and RRD files for tuner_id/tuner_number/callsign
sub _signal_update {
  my ($self,$c,
      $tuner_id,$tuner_number,
      $channel,$callsign,$virtual_channel,$channel_details) = @_;

  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $now_epoch = time;

  # create new record if needed.  Station moving to new channel qualifies
  my $entry = $c->model('DB::Signal')
               ->find({'tuner_id' => $tuner_id,
                       'tuner_number' => $tuner_number,
                       'callsign' => $callsign,});
  if (! $entry) {
    my $spot = {
      'rx_date'         => $sqlite_now,
      'first_rx_date'   => $sqlite_now,
      'rf_channel'      => $channel,
      'strength'        => $channel_details->{'strength'},
      'sig_noise'       => $channel_details->{'sig_noise'},
      'tuner_id'        => $tuner_id,
      'tuner_number'    => $tuner_number,
      'callsign'        => $callsign,
      'virtual_channel' => $virtual_channel, };
    $entry = $c->model('DB::Signal')->create($spot);
    if (! $entry) {
      return 0
    }
  }
  $entry->update({'rx_date'    => $sqlite_now,
                  'rf_channel' => $channel,
                  'strength'   => $channel_details->{'strength'},
                  'sig_noise'  => $channel_details->{'sig_noise'}});

  my $rrd_file = join '_', ($tuner_id,$tuner_number,$callsign);
  $rrd_file = $c->config->{rrd_dir} . "/$rrd_file.rrd";

  if (! -r $rrd_file) {
    RRDs::create( $rrd_file, '--start', '-6hours', '--step', '60',
                  "DS:strength:GAUGE:300:0:100",
                  "DS:sig_noise:GAUGE:300:0:100",
                  "RRA:MAX:.99:1:288000",
                  "RRA:MAX:.99:60:131040" );
    # short duration DX won't have a graph point unless it's stretched out
    for (my $i = 3; $i > 0; $i--) {
      my $te = $now_epoch - 60*$i;
      RRDs::update(
        $rrd_file, '--template', 'strength:sig_noise',
        "$te:$channel_details->{strength}:$channel_details->{sig_noise}"
      );
    }
  }

  if ($now_epoch-600 > RRDs::last($rrd_file)) {
    for (my $i = 3; $i > 0; $i--) {
      my $te = $now_epoch - 60*$i;
      RRDs::update(
        $rrd_file, '--template', 'strength:sig_noise',
        "$te:$channel_details->{strength}:$channel_details->{sig_noise}"
      );
    }
  }

  RRDs::update(
    $rrd_file, '--template', 'strength:sig_noise',
    "$now_epoch:$channel_details->{strength}:$channel_details->{sig_noise}"
  );
  return 1;
}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2013 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
