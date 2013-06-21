package tvdx::Controller::RawSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::SQLite;
use DateTime::Format::HTTP;
use XML::Simple;
use LWP::Simple;
use RRDs;
use List::MoreUtils 'none';


BEGIN { extends 'Catalyst::Controller'; }

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

sub raw_spot :Global {
  my ( $self, $c ) = @_;

  # the current time formatted to sqlite format (UTC time zone)
  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $now_epoch = time;

  # xml with information from (client) scanlog.pl
  my $href = XMLin($c->request->params->{'xml'}, ForceArray => ['rf_channel'] );

  my ($junk,$tuner_id,$tuner_number) = split /_/, $href->{'user_id'};

  # log if tuner isn't found
  if (! $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id})) {
    open L, ">>/tmp/unknown_tuner" or return 0;
    print L "$sqlite_now: tuner_id $tuner_id not found in tuner table\n";
    close L;
    $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
    $c->response->status(403);
    return;
  }

  RAWSPOT: foreach my $raw_channel (@{$href->{'rf_channel'}}) {
    my $channel           = $raw_channel->{name};
    my $modulation        = $raw_channel->{modulation};
    my $strength          = $raw_channel->{strength};
    my $sig_noise         = $raw_channel->{sig_noise};
    my $symbol_err        = $raw_channel->{symbol_err};
    my $tsid              = $raw_channel->{tsid};
    my %virtual           = $raw_channel->{virtual};
    my $reporter_callsign = $raw_channel->{reporter_callsign};

    # return callsign or undef if it can't be determined and a virtual
    # channel for legacy column in fcc table
    ($callsign,$fcc_virtual) = _find_call($raw_channel);
    $c->log->debug("channel $channel:found callsign: $callsign\n");

    # record signal strength and possibly sig_noise if no call was found
    if (! defined $callsign) {
      _rrd_update_nocall($raw_channel);
      next RAWSPOT;
    }

    # add or update fcc table if needed
    if (! $self->_call_current($c,$callsign,$channel,$virtual_channel)) {
      next RAWSPOT;
    }
    # add or update virtual channel table
    if (! $self->_virtual_current($c,$callsign,$raw_channel)) {
      next RAWSPOT;
    }
    # add or update tsid table if needed
    if (! $self->_tsid_current($c,$callsign,$raw_channel)) {
      next RAWSPOT;
    }
    # update rrd file and Signal table
    _signal_update($c,$tuner_id,$tuner_number,$callsign,$raw_channel);
  }

  $c->response->body('OK');
  $c->response->status(202);
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
