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

  foreach my $frequency ($json->signal) {
    my $pi = defined $json->{signal}->{frequency}->{pi} ? $json->{signal}->{frequency}->{pi} : undef;
    next unless $pi;

    # add or update fcc table if needed and return FmFcc table fcc_key
    my $fcc_key = _cru_fcc_key($c,$frequency,$pi);
    unless (defined $fcc_key) {
      $c->log->warn("Could not update/create FM FCC table");
      next;
    }


    # create or update report
    my $entry =
      $c->model('DB::FmSignalReport')->search({'tuner_key' =>$json->{tuner_key},
                                               'frequency' => $frequency,
                                               'fcc_key' => $fcc_key});
#TODO: see line 117 of Root.pm and etc.

  }

  $c->response->body('OK');
  $c->response->status(202);
}


# create, retrieve or update fcc_key from fm_fcc table
sub _cru_fcc_key {
  my ($self,$c,$frequency,$pi) = @_;

  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  my ($fcc_row) = $c->model('DB::FmFcc')->find({'frequency' => $frequency,
                                                'pi' => $pi,
                                                'end_date' => { '==', undef}});
  if (!defined $fcc_row || $fcc_row == 0 || (DateTime::Format::MySQL->parse_datetime($fcc_row->last_fcc_lookup) < $yesterday)) {
      return undef unless (_update_fm_fcc($c)); 
      $fcc_row = $c->model('DB::FmFcc')->find({'frequency' => $frequency,
                                                'pi' => $pi,
                                                'end_date' => { '==', undef}});
  }

  if (!defined $fcc_row || $fcc_row == 0 || (DateTime::Format::MySQL->parse_datetime($fcc_row->last_fcc_lookup) < $yesterday)) {
    $c->log->error("Couldn't retrieve fcc_key from fm_fcc table");
    return undef;
  }

  return $fcc_row->fcc_key;
}


# update fm_fcc table from remote database
sub _update_fm_fcc {
  my ($self,$c) = @_;

  my $sql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);

  # only try URL at most once an hour
  next unless $tvdx::fm_get_attempt_epoch < (time - 3600);
  $tvdx::fm_get_attempt_epoch = time;

  my $dom = Mojo::DOM->new(get($c->config->{'nrsc_pi_url'}));
  return undef unless defined $dom;

  # parse html and create or update fm_fcc for each station in table
  for my $row ($dom->find('tr')->each) {
    my $td = $row->find('td')->to_array;
    next unless all {$_} (@{$td}[0..6]);
    my $call = $td->[0]->at('a')->text;
    my $hex_pi = $td->[1]->at('code')->text;
    my $pi = hex $hex_pi;
    my $frequency = $td->[2]->text;
    my $facility_id = $td->[3]->at('a')->text;
    my $city = $td->[4]->text;
    my $state = $td->[5]->text;
#TODO: get class, erp, haat from FCC
    my $class = 'unknown';

    my $latlong = $td->[6]->text;
    $latlong = substr($latlong,1);
    $latlong =~ s/ +//gs;
    my (@ll) = split /[^\d.NSEW]/, $latlong;

    my $lat = $ll[0] + $ll[1]/60 + $ll[2]/3600;
    $lat *= -1 if $ll[3] eq 'S';
    my $lon = $ll[4] + $ll[5]/60 + $ll[6]/3600;
    $lon *= -1 if $ll[7] eq 'W';

    # create entry in fm_fcc?
    my ($fcc_row) = $c->model('DB::FmFcc')->find({'frequency' => $frequency,
                                                  'pi' => $pi,
                                                  'end_date' =>{ '==', undef}});
    if (!defined $fcc_row || $fcc_row == 0) {
      unless (all {defined $_} ($pi,$call,$class,$lat,$lon,$sql_now,$city,$state)) {
        $c->log->warn("Missing or bad data in ".$c->config->{'nrsc_pi_url'}." Row was: $pi,$call,$class,$lat,$lon,$sql_now,$city,$state");
        next;
      }
      my $entry = $c->model('DB::FmFcc')->create({
        'pi' => $pi,
        'callsign' => $call,
        'frequency' => $frequency,
        'facility_id' => $facility_id,
        'start_date' => $sql_now,
        'city_state' => "$city, $state",
        'last_fcc_lookup' => $sql_now,
      });
      if (!$entry) {
        $c->log->error("Couldn't create new fm_fcc row with $pi,$call,$class,$lat,$lon,$sql_now,$city,$state");
        next;
      }
    }
    # else row exists, just update it.
    else {
      $fcc_row->update({
        'pi' => $pi,
        'callsign' => $call,
        'frequency' => $frequency,
        'facility_id' => $facility_id,
        'start_date' => $sql_now,
        'city_state' => "$city, $state",
        'last_fcc_lookup' => $sql_now,
      });
    }
  }

  return 1;
}



=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2020 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
