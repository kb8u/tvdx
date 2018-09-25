package tvdx::Controller::RawSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::HTTP;
use LWP::Simple;
use RRDs;
use List::MoreUtils qw(all zip);
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

  # the current time formatted to mysql format (UTC time zone)
  my $mysql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);
  my $now_epoch = time;
  # 24 hours ago
  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  # json with information from (client) scanlog.pl
  my $json = $c->req->data;

  my (undef,$tuner_id,$tuner_number) = split /_/, $json->{'user_id'};

  # log if tuner isn't found
  if (! $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id})) {
    $c->log->info("tuner_id $tuner_id is not registered with site");
    $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
    $c->response->status(403);
    return;
  }

  # log if tuner is in tuner_debug table
  if ($c->model('DB::TunerDebug')->find({'tuner_id'=>$tuner_id})) {
    {
      local $Data::Dumper::Indent = 1;
      $c->log->info("$tuner_id $tuner_number in tuner_debug table:",Dumper($json));
    }
  }

  RAWSPOT: for my $channel (keys %{$json->{'rf_channel'}}) {
    my $channel_details = $json->{'rf_channel'}->{$channel};

    # need at least a strength to log
    next RAWSPOT unless $channel_details->{strength};
    # ignore bogus channel numbers
    next RAWSPOT if ($channel !~ /^\d+$/);
    next RAWSPOT if ($channel < 2 || $channel > 69);

    # arguments to subroutines
    my $args = { 'c' => $c,
                 'json' => $json,
                 'tuner_id' => $tuner_id,
                 'tuner_number' => $tuner_number,
                 'channel' => $channel,
                 'channel_details' => $channel_details,
                 'now_epoch' => $now_epoch,
                 'mysql_now' => $mysql_now,
                 'yesterday' => $yesterday };

    # return callsign or undef if it can't be determined and a virtual
    # channel for legacy column in fcc table
    ($args->{callsign},$args->{fcc_virtual}) = $self->_find_call($args);

    # record signal strength and sig_noise in rrds
    $self->_rrd_update($args);

    # update SignalReport table
    unless ($self->_signalreport_update($args)) {
      $c->response->body('FAIL');
      $c->response->status(400);
      return;
    }

    # nothing further to log if no decode
    next RAWSPOT unless defined $args->{callsign};

    # add or update virtual channel table
    $self->_virtual_current($args);

    # add or update tsid table if needed
    $self->_tsid_current($args);
  }

  $c->response->body('OK');
  $c->response->status(202);
}


sub _lu_call {
  my ($args,$possible_call) = @_;
  # update or create rabbitears_call if entry is old or missing
  my ($re_call_find) = $args->{c}->model('DB::RabbitearsCall')
                                 ->find({'callsign' => $possible_call});
  my $rlu;
  if (   (! $re_call_find)
      || (DateTime::Format::MySQL->parse_datetime(
            $re_call_find->last_re_lookup) < $args->{yesterday})) {
    $rlu = get($RABBITEARS_TVQ . "call=$possible_call");

    return undef if ($rlu eq 'Error connecting to RabbitEars database');

    if (defined $rlu) {
      # create or update rabbitears_call table
      if (! $re_call_find) {
        $args->{c}->model('DB::RabbitearsCall')->create({
           'callsign' => $possible_call,
           're_rval' => $rlu,
           'last_re_lookup' => $args->{mysql_now},});
      }
      else {
        $re_call_find->update({
          'last_re_lookup' => $args->{mysql_now},
          're_rval' => $rlu,});
      }
    }
  }
  else {
    $rlu = $re_call_find->re_rval;
  }

  return $rlu;
}


sub _rrd_not_pending {
  my ($rrd) = @_;

  $tvdx::socket_io->send("PENDING $rrd\n");
  my $response;
  $tvdx::socket_io->recv($response, 16384);
  my ($status) = split /\s/, $response;

  return ($status !~ /^\-?\d+$/ || $status > 0) ? 0 : 1;
}


# determine callsign from raw channel information.  Updates (if > 1 day old)
# rabbitears_call, rabbitears_tsid and fcc tables. 
sub _find_call {
  my ($self,$args) = @_;

  my $ch = $args->{channel_details};

  # nothing to look up if there's no modulation
  return (undef,undef) if $ch->{modulation} eq 'none';

  # determine virtual channel for fcc table
  # use channel number if there are no virtuals
  my $fcc_virt = $args->{channel};
  if (%{$ch->{virtual}}) {
    # any subchannel will do, just choose a random one
    my ($some_key) = keys %{$ch->{virtual}}; 
    if (exists $ch->{virtual}{$some_key}{channel}) {
      ($fcc_virt) = split /\./,$ch->{virtual}{$some_key}{channel};
    }
  }

  # transmitter power, location, etc.  Order is from rabbitears.info lookup
  # fcc_virt key, value is also in %transmitter
  my %transmitter;
  my @rabbitears_keys = qw(call fcc_channel city state rcamsl erp
      n_or_s lat_deg lat_min lat_sec w_or_e lon_deg lon_min lon_sec
      digital_tsid analog_tsid observed_tsid);

  # try tsid (excepting 0, 1 and greater than 65535) and channel
  if ($ch->{tsid} && $ch->{tsid} > 1 && $ch->{tsid} < 65536) {
    # update or create rabbitears_tsid if entry is old or missing
    my ($re_tsid_find) = $args->{c}->model('DB::RabbitearsTsid')
                                   ->find({'tsid'=>$ch->{tsid}});
    my $rlu;
    if (   (! $re_tsid_find)
        || (DateTime::Format::MySQL->parse_datetime(
              $re_tsid_find->last_re_lookup) < $args->{yesterday})) {
      $rlu = get($RABBITEARS_TVQ . "tsid=$ch->{tsid}");
      undef $rlu if $rlu eq 'Error connecting to RabbitEars database';

      if (defined $rlu) {
        # create or update rabbitears_tsid table
        if (! $re_tsid_find) {
          $args->{c}->model('DB::RabbitearsTsid')->create({
             'tsid' => $ch->{tsid},
             're_rval' => $rlu,
             'last_re_lookup' => $args->{mysql_now},});
        }
        else {
          $re_tsid_find->update({
            're_rval' => $rlu,
            'last_re_lookup' => $args->{mysql_now},});
        }
      }
    }
    else {
      $rlu = $re_tsid_find->re_rval;
    }
    if (defined $rlu) {
      # discard tsid's on other channels
      my @rlu;
      foreach my $line (split /\n/, $rlu) {
        my @rlu_values = split /\s*\|/,$line;
        if ($args->{channel} == $rlu_values[1]) {
          push @rlu, { zip @rabbitears_keys, @rlu_values };
        }
      }

      # use last line if all the calls are the same
      @rlu = ($rlu[$#rlu]) if all { $_->{call} eq $rlu[0]->{call} } @rlu;
      # use match if it's the only one
      if (scalar @rlu == 1 && defined $rlu[0]) {
        %transmitter = %{$rlu[0]};
        $transmitter{fcc_virt} = $fcc_virt;
      }

      # try reporter_callsign if there's more than one
      if (scalar @rlu > 1 && $ch->{reporter_callsign}) {
        foreach my $h (@rlu) {
          if ($ch->{reporter_callsign} eq $h->{call}) {
            %transmitter = %{$h};
            $transmitter{fcc_virt} = $fcc_virt;
            last;
          }
        }
      }
    }
  }

  # try callsign and channel unless TSID lookup worked
  unless (%transmitter) {
    # loop over virtual channels, look for something resembling a callsign
    VIRT_CHAN: for my $program (keys %{$ch->{virtual}}) {
      next if ($ch->{virtual}{$program}{name} !~ /([CWKX](\d\d)*[A-Z]{2,3})/i);
      my $possible_call = uc $1;

      my $rlu = _lu_call($args,$possible_call);
      if (defined $rlu) {
        foreach my $s (split /\n/, $rlu) {
          my %rlu_values;
          @rlu_values{@rabbitears_keys} = split /\s*\|/,$s;
          if ($args->{channel} == $rlu_values{fcc_channel}) {
            %transmitter = %rlu_values;
            $transmitter{fcc_virt} = $fcc_virt;
            last VIRT_CHAN;
          }
        }
      }
    }
  }

  if (!%transmitter && $ch->{reporter_callsign}) {
    my $rlu = _lu_call($args,$ch->{reporter_callsign});
    if (defined $rlu) {
      foreach my $s (split /\n/, $rlu) {
        my %rlu_values;
        @rlu_values{@rabbitears_keys} = split /\s*\|/,$s;
        if ($args->{channel} == $rlu_values{fcc_channel}) {
          %transmitter = %rlu_values;
          $transmitter{fcc_virt} = $fcc_virt;
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
  $lat_decimal = -1 * $lat_decimal if ($transmitter{n_or_s} eq 'S' || $transmitter{n_or_s} eq '-');
  my $lon_decimal =    $transmitter{lon_deg}
                     + $transmitter{lon_min}/60
                     + $transmitter{lon_sec}/3600;
  $lon_decimal = -1 * $lon_decimal if ($transmitter{w_or_e} eq 'W' || $transmitter{w_or_e} eq '-');

  # update fcc table with %transmitter, if needed
  my ($fcc_call) = $args->{c}->model('DB::Fcc')
                     ->find({'callsign' => $transmitter{call}});

  # new record if FCC data is missing
  if (! $fcc_call) {
    $args->{c}->model('DB::Fcc')->create({
      'callsign'        => $transmitter{call},
      'rf_channel'      => $transmitter{fcc_channel},
      'latitude'        => $lat_decimal,
      'longitude'       => $lon_decimal,
      'start_date'      => $args->{mysql_now},
      'virtual_channel' => $transmitter{fcc_virt},
      'city_state'      => $location,
      'erp_kw'          => $erp,
      'rcamsl'          => $rcamsl,
      'last_fcc_lookup' => $args->{mysql_now}, });
  }
  # update record if FCC data is old
  if (   $fcc_call
      && DateTime::Format::MySQL
         ->parse_datetime($fcc_call->last_fcc_lookup) < $args->{yesterday}) {
    $fcc_call->update({
      'rf_channel'      => $transmitter{fcc_channel},
      'latitude'        => $lat_decimal,
      'longitude'       => $lon_decimal,
      'virtual_channel' => $transmitter{fcc_virt},
      'city_state'      => $location,
      'erp_kw'          => $erp,
      'rcamsl'          => $rcamsl,
      'last_fcc_lookup' => $args->{mysql_now} });
  }

  if (defined $transmitter{call} && defined $transmitter{fcc_virt}) {
    return ($transmitter{call},$transmitter{fcc_virt});
  }
  else {
    return (undef,undef);
  }
}


# create or update rrd for channels
sub _rrd_update {
  my ($self,$args) = @_;

  my $ch = $args->{channel_details};

  my $strength = $args->{json}{rf_channel}{$args->{channel}}{strength};
  my $sig_noise = $args->{json}{rf_channel}{$args->{channel}}{sig_noise};

  # RF channel rrd
  my $rrd_file = join '_', ($args->{tuner_id},
                            $args->{tuner_number},
                            $args->{channel});
  $rrd_file = $args->{c}->config->{rrd_dir} . "/$rrd_file.rrd";

  if ( _rrd_not_pending($rrd_file) && ! -r $rrd_file) {
    RRDs::create( $rrd_file, '--start', '-6hours', '--step', '60',
                  "DS:strength:GAUGE:300:0:100",
                  "DS:sig_noise:GAUGE:300:0:100",
                  "RRA:MAX:.99:1:288000",
                  "RRA:MAX:.99:60:131040" );
  }

  RRDs::update( $rrd_file, '--daemon', $args->{c}->config->{socket},
                '--template', 'strength:sig_noise',
                "N:$strength:$sig_noise");

  return 1 unless $args->{callsign};

  # tuner and callsign rrd
  $rrd_file = join '_', ($args->{tuner_id},
                            $args->{tuner_number},
                            $args->{callsign});
  $rrd_file = $args->{c}->config->{rrd_dir} . "/$rrd_file.rrd";

  if ( _rrd_not_pending($rrd_file) && ! -r $rrd_file) {
    RRDs::create( $rrd_file, '--start', '-6hours', '--step', '60',
                  "DS:strength:GAUGE:300:0:100",
                  "DS:sig_noise:GAUGE:300:0:100",
                  "RRA:MAX:.99:1:288000",
                  "RRA:MAX:.99:60:131040" );
    # short duration DX won't have a graph point unless it's stretched out
    for (my $i = 3; $i > 0; $i--) {
      my $te = $args->{now_epoch} - 60*$i;
      RRDs::update( $rrd_file, '--daemon', $args->{c}->config->{socket},
                    '--template', 'strength:sig_noise',
                    "$te:$ch->{strength}:$ch->{sig_noise}" );
    }
  }

  if (_rrd_not_pending($rrd_file) && $args->{now_epoch}-600 > RRDs::last($rrd_file)) {
    for (my $i = 3; $i > 0; $i--) {
      my $te = $args->{now_epoch} - 60*$i;
      RRDs::update( $rrd_file, '--daemon', $args->{c}->config->{socket},
                    '--template', 'strength:sig_noise',
                   "$te:$ch->{strength}:$ch->{sig_noise}" );
    }
  }

  RRDs::update( $rrd_file, '--daemon', $args->{c}->config->{socket},
                '--template', 'strength:sig_noise',
                "$args->{now_epoch}:$ch->{strength}:$ch->{sig_noise}" );
}


sub _signalreport_update {
  my ($self,$args) = @_;

  my $ch = $args->{channel_details};
  my $callsign = $args->{callsign} ? $args->{callsign} : undef;
  my $virtual_channel = $args->{fcc_virtual} ? $args->{fcc_virtual} : undef;

  # update SignalReport with or without callsign
  # Create new callsign record?  Station moving to new channel qualifies
  my $entry = $args->{c}->model('DB::SignalReport')
                        ->search({'tuner_id' => $args->{tuner_id},
                                  'tuner_number' => $args->{tuner_number},
                                  'rf_channel' => $args->{channel},
                                  'callsign' => $callsign,})->first;
  # test $entry as scalar (ResultSet boolean is always true)
  if ($entry == 0) {
    my $spot = {
      'rx_date'         => $args->{mysql_now},
      'first_rx_date'   => $args->{mysql_now},
      'rf_channel'      => $args->{channel},
      'strength'        => $ch->{'strength'},
      'sig_noise'       => $ch->{'sig_noise'},
      'tuner_id'        => $args->{tuner_id},
      'tuner_number'    => $args->{tuner_number},
      'callsign'        => $callsign,
      'virtual_channel' => $virtual_channel, };
    $entry = $args->{c}->model('DB::SignalReport')->create($spot);
    if (! $entry) {
      return 0
    }
  }
  $entry->update({'rx_date'    => $args->{mysql_now},
                  'rf_channel' => $args->{channel},
                  'strength'   => $ch->{strength},
                  'sig_noise'  => $ch->{sig_noise}});
  return 1;
}


# Update or create virtual table entry for callsign
sub _virtual_current {
  my ($self,$args) = @_;

  my $ch = $args->{channel_details};

  # process each virtual channel
  for my $program (keys %{$ch->{virtual}}) {
    # skip if missing name or channel
    next unless $ch->{virtual}{$program}{name};
    next unless $ch->{virtual}{$program}{channel};

    # sometimes the name or channel has bit errors
    next if $ch->{virtual}{$program}{name} =~ /[^[:ascii:]]/;
    next if $ch->{virtual}{$program}{channel} =~ /[^[:ascii:]]/;

    # sometimes trailing whitespace is added
    $ch->{virtual}{$program}{name} =~ s/\s+$//;
    $ch->{virtual}{$program}{channel} =~ s/\s+$//;

    my $v_row =
      $args->{c}->model('DB::PsipVirtual')->search(
        {'callsign' => $args->{callsign},
         'name'     => $ch->{virtual}{$program}{name},
         'channel'  => $ch->{virtual}{$program}{channel}});

    # all new entry? Test $v_row as scalar (ResultSet boolean is always true)
    if ($v_row == 0) {
      $args->{c}->model('DB::PsipVirtual')->create({
        'rx_date'  => $args->{mysql_now},
        'name'     => $ch->{virtual}{$program}{name},
        'channel'  => $ch->{virtual}{$program}{channel},
        'callsign' => $args->{callsign}});
      next;
    }
    # else update existing row
    else {
      while (my $psip = $v_row->next) {
        $psip->update({'rx_date'  => $args->{mysql_now}});
      }
    }
  }
}

  
# Update or create tsid table entry for callsign
sub _tsid_current {
  my ($self,$args) = @_;

  my $ch = $args->{channel_details};

  # nothing to do if tsid is missing or invalid
  unless ($ch->{tsid} && $ch->{tsid} > 1 && $ch->{tsid} < 65536) { return }

  my ($tsid_row) = $args->{c}->model('DB::Tsid')->search(
        {'callsign' => $args->{callsign},
         'tsid'     => $ch->{tsid}})->first;
  # all new entry? Test $tsid_row as scalar (ResultSet boolean is always true)
  if ($tsid_row == 0) {
    $args->{c}->model('DB::Tsid')->create({
      'rx_date'  => $args->{mysql_now},
      'tsid'     => $ch->{tsid},
      'callsign' => $args->{callsign}});
  }
  # else update existing row
  else {
    $tsid_row->update({'rx_date'  => $args->{mysql_now}});
  }
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
