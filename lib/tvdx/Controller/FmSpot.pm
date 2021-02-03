package tvdx::Controller::FmSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::HTTP;
use LWP::Simple;
use Mojo::DOM;
use List::Util 'all';
use Data::Dumper;
use Compress::Bzip2 ':utilities';
use JSON::XS;


BEGIN { extends 'Catalyst::Controller::REST' }

=head1 NAME

tvdx::Controller::FmSpot - Catalyst Controller for FM DX

=head1 DESCRIPTION

Functions for FM DX

=head1 METHODS

=cut


=head2 fm_spot

Accept compressed spots from client and adds entries to database

=cut

sub fm_spot :Global :ActionClass('REST') {}

sub fm_spot_POST :Global {
  my ( $self, $c ) = @_;
  # the current time formatted to mysql format (UTC time zone)
  my $mysql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);
  my $now_epoch = time;
  # 24 hours ago
  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );
  # json with information from (client) scanlog.pl
  my $json = ($c->req->headers->content_type eq 'application/octet-stream')
           ? decode_json(memBunzip($c->req->body_data))
           : $c->req->data;
  my $tuner_key = $json->{'tuner_key'};

  # log if tuner isn't found
  if (! $c->model('DB::FmTuner')->find({'tuner_key'=>$tuner_key})) {
    $c->log->info("tuner_key $tuner_key is not registered with site");
    $c->response->body("FAIL: Tuner $tuner_key is not registered with site");
    $c->response->status(403);
    return;
  }

  # log if tuner is in tuner_debug table
  if ($c->model('DB::TunerDebug')->find({'tuner_id'=>$tuner_key})) {
    {
      local $Data::Dumper::Indent = 1;
      $c->log->info("$tuner_key in tuner_debug table:",Dumper($json));
    }
  }

  foreach my $frequency (keys %{$json->{signal}}) {
    my $pi_code = defined $json->{signal}{$frequency}{pi_code}
           ? $json->{signal}{$frequency}{pi_code}
           : undef;
    next unless $pi_code;

    my $s = defined $json->{signal}{$frequency}{s}
           ? $json->{signal}{$frequency}{s}
           : undef;

    my ($fcc_row) = $c->model('DB::FmFcc')->find({'frequency' => $frequency,
                                                  'pi_code' => $pi_code,
                                                  'end_date' => undef});
    unless (defined $fcc_row && $fcc_row) {
      $c->log->warn("Couldn't find fm_fcc entry for frequency $frequency pi_code $pi_code");
      next;
    }

    # create or update report
    my $entry =
      $c->model('DB::FmSignalReport')->search({'tuner_key' =>$json->{tuner_key},
                                               'frequency' => $frequency,
                                               'fcc_key' => $fcc_row->fcc_key});
    if (!defined $entry || $entry == 0) {
      $c->model('DB::FmSignalReport')
        ->create({'rx_date' => $mysql_now,
                  'first_rx_date' => $mysql_now,
                  'frequency' => $frequency,
                  'tuner_key' =>$json->{tuner_key},
                  'fcc_key' => $fcc_row->fcc_key},
                  'strength' => $s);
      next;
    }
    else {
      $entry->update({'rx_date' => $mysql_now, 'strength' => $s});
    }
  }

  $c->response->body('OK');
  $c->response->status(202);
}


=head2 fm_map_data

Arguments are tuner_key that sent the reception reports to fm_spot and a
string for time period; 'ever' gets all data ever, otherwise just the last
24 hours. Returns JSON data for display by page created by sub fm_one_tuner_map

=cut


sub fm_map_data :Global {
  my ($self, $c, $tuner_key, $period) = @_;

  # error if tuner is not in d.b.
  unless (defined $tuner_key {
    $c->response->body("FAIL: missing tuner_key");
    $c->response->status(403);
    $c->detach();
  }
  if (! $c->model('DB::FmTuner')->find({'tuner_key'=>$tuner_key})) {
    $c->response->body("FAIL: Tuner $tuner_key is not registered with site");
    $c->response->status(403);
    $c->detach();
  }

}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2021 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
