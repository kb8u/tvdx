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

  RAWSPOT: foreach my $channel (keys %{$json->{'rf_channel'}}) {
    my $channel_details       = $json->{'rf_channel'}->{$channel};
    my $modulation        = $channel_details->{modulation};
    my $strength          = $channel_details->{strength};
    my $sig_noise         = $channel_details->{sig_noise};
    my $symbol_err        = $channel_details->{symbol_err};
    my $tsid              = $channel_details->{tsid};
    my %virtual           = %{$channel_details->{virtual}};
    my $reporter_callsign = $channel_details->{reporter_callsign};
$c->log->debug("#####channel: $channel strength: $strength");

    # return callsign or undef if it can't be determined and a virtual
    # channel for legacy column in fcc table
    my ($callsign,$fcc_virtual) = _find_call($channel_details,$channel);
if (defined $callsign) {
    $c->log->debug("#####channel $channel:found callsign: $callsign\n");
}
next RAWSPOT;
    # record signal strength and possibly sig_noise if no call was found
    if (! defined $callsign) {
      _rrd_update_nocall($channel_details);
      next RAWSPOT;
    }

    # add or update fcc table if needed
    if (! $self->_call_current($c,$callsign,$channel,$fcc_virtual)) {
      next RAWSPOT;
    }
    # add or update virtual channel table
    if (! $self->_virtual_current($c,$callsign,$channel_details)) {
      next RAWSPOT;
    }
    # add or update tsid table if needed
    if (! $self->_tsid_current($c,$callsign,$channel_details)) {
      next RAWSPOT;
    }
    # update rrd file and Signal table
    _signal_update($c,$tuner_id,$tuner_number,$callsign,$channel_details);
  }

  $c->response->body('OK');
  $c->response->status(202);
}


# determine callsign from raw channel information
sub _find_call {
  my ($channel_details,$tuner_channel) = @_;
  my ($call,$fcc_channel,
      $city,$state,
      $rcamsl,$erp,
      $n_or_s,$lat_deg,$lat_min,$lat_sec,
      $w_or_e,$lon_deg,$lon_min,$lon_sec,
      $digital_tsid,$analog_tsid,$observed_tsid);

  # try tsid (excepting 0, 1 and greater than 32766) and channel
  if (   $channel_details->{tsid} 
      && $channel_details->{tsid} > 1
      && $channel_details->{tsid} < 32767) {
######## this works, but is very slow and hammers on rabbitears.
######## try cacheing it, or use DBIx to query directly
    my $rlu = get($RABBITEARS_TVQ . "tsid=$channel_details->{tsid}");
    if (defined $rlu) {
      foreach my $s (split /\n/, $rlu) {
        my ($s_call,$s_fcc_channel,
            $s_city,$s_state,
            $s_rcamsl,$s_erp,
            $s_n_or_s,$s_lat_deg,$s_lat_min,$s_lat_sec,
            $s_w_or_e,$s_lon_deg,$s_lon_min,$s_lon_sec,
            $s_digital_tsid,$s_analog_tsid,$s_observed_tsid) = split /\s*\|/,$s;
        if ($tuner_channel == $s_fcc_channel) {
          ($call,$fcc_channel,
           $city,$state,
           $rcamsl,$erp,
           $n_or_s,$lat_deg,$lat_min,$lat_sec,
           $w_or_e,$lon_deg,$lon_min,$lon_sec,
           $digital_tsid,$analog_tsid,$observed_tsid)
          =
          ($s_call,$s_fcc_channel,
           $s_city,$s_state,
           $s_rcamsl,$s_erp,
           $s_n_or_s,$s_lat_deg,$s_lat_min,$s_lat_sec,
           $s_w_or_e,$s_lon_deg,$s_lon_min,$s_lon_sec,
           $s_digital_tsid,$s_analog_tsid,$s_observed_tsid);
          last;
        }
      }
    }
  }
  # else try callsign and channel
  else {
  }
  if (defined $call && defined $fcc_channel) {
    return ($call,$fcc_channel);
  }
  else {
    return undef
  }
}


# Check or update (if > 1 day old) or create virtual table entry for callsign
# Returns 1 on success, 0 on failure.
sub _virtual_current {
  my ($self,$c,$callsign,$channel_details) = @_;

  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  # process each virtual channel
  for my $v_channel (keys %{$channel_details->{virtual}}) {
    my ($v_row) = $c->model('DB::Virtual')
                    ->find({'callsign' => $callsign,
                            'channel' =>$channel_details->{virtual}->{$v_channel}});

    # all new entry?
    if (!$v_row) {
      # create new row
      return 1;
    }

    # check if last reception date is older than a day
    if (DateTime::Format::SQLite->parse_datetime($v_row->rx_date)<$yesterday) {
      # update existing row
      return 1;
    }
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
