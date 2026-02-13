package tvdx::Controller::FmSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::ISO8601;
use DateTime::Duration;
use Math::Round 'nearest';
use List::Util 'any';
# leaks memory, have to use Geo::Calc even though it's much slower
#use Geo::Calc::XS;
use Geo::Calc;
use GIS::Distance;
use GIS::Distance::Fast;
use Data::Dumper;
use Compress::Bzip2 ':utilities';
use JSON::XS;
use Try::Tiny;
use Email::Address;
use Regexp::Common;


BEGIN { extends 'Catalyst::Controller::REST' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in tvdx.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

tvdx::Controller::FmSpot - Catalyst Controller for FM DX

=head1 DESCRIPTION

Functions for FM DX

=head1 METHODS

=cut


=head2 fm_spot_POST

Accept compressed spots from client and adds entries to database

=cut

sub fm_spot :Global :ActionClass('REST') {}

sub fm_spot_POST :Global {
  my ( $self, $c ) = @_;

  # the current time formatted to mysql format (UTC time zone)
  my $dt_now = DateTime->now;
  my $mysql_now = DateTime::Format::MySQL->format_datetime($dt_now);
  $dt_now->set_time_zone('UTC');
  my $dt_30min = DateTime::Duration->new(minutes=>30);
  # json with information from (client) scanlog.pl
  my $json = ($c->req->headers->content_type eq 'application/octet-stream')
           ? decode_json(memBunzip($c->req->body_data))
           : $c->req->data;

  my $tuner_key = $json->{'tuner_key'};

  my $tuner = $self->_get_tuner($c,$tuner_key);
  $tuner->update({'ipaddress' => $c->request->address});

  unless ($c->req->headers->content_type eq 'application/octet-stream') {
    if (!exists $json->{'password'} || $tuner->user_key->password ne $json->{'password'}) {
      my $pw_error = exists $json->{'password'}
                   ? "has bad password ".$json->{'password'}
                   : "missing password in JSON";
      $c->log->warn("tuner_key $tuner_key $pw_error");
      $c->response->body("invalid password");
      $c->response->status(403);
      return;
    }
  }

  # log if tuner is in tuner_debug table
  if ($c->model('DB::TunerDebug')->find({'tuner_id'=>$tuner_key})) {
    {
      local $Data::Dumper::Indent = 1;
      $c->log->warn("$tuner_key in tuner_debug table:",Dumper($json));
    }
  }

  foreach my $frequency (keys %{$json->{signal}}) {
    if ($frequency !~ /^\d{8,9}/ || ($frequency-100000) % 200000) {
      delete $json->{signal}{$frequency};
      next;
    }

    my $pi_code = defined $json->{signal}{$frequency}{pi_code}
                ? $json->{signal}{$frequency}{pi_code}
                : undef;
    unless ($pi_code && $pi_code =~ /^\d{1,5}$/) {
      delete $json->{signal}{$frequency};
      next;
    }
    # 0 and FFFF are invalid but some stations use it anyway
    if ($pi_code == 65535 || $pi_code == 0) {
      delete $json->{signal}{$frequency};
      next;
    }

    my $s = defined $json->{signal}{$frequency}{s}
          ? $json->{signal}{$frequency}{s}
          : undef;
    my $re_num_real = $RE{num}{real};
    if ($s && $s !~ /^$re_num_real$/) {
      delete $json->{signal}{$frequency};
      next;
    }

    my $time;
    if (defined $json->{signal}{$frequency}{time}) {
      try {
        my $sig_dt = DateTime::Format::ISO8601->parse_datetime($json->{signal}{$frequency}{time});
        # DateTime::Format::MySQL is timezone agnostic so coerce it to UTC
        $sig_dt->set_time_zone('UTC');
        if ($sig_dt < $dt_now-$dt_30min || $sig_dt > $dt_now) {
          $time = $mysql_now;
        } else {
          $time = DateTime::Format::MySQL->format_datetime($sig_dt);
        }
      }
      catch {
        $time = $mysql_now
      };
    } else {
       $time = $mysql_now;
    }
    $json->{signal}{$frequency}{time} = $time;
  }

  _upsert_all($self,$c,$json) if scalar %{$json->{signal}} > 0;

  $c->response->body('OK');
  $c->response->status(202);
}


sub _upsert_all {
  my ($self, $c, $json) = @_;

  my $storage = $c->model('DB')->storage();

  my $sql = 'insert ignore into fm_signal_report (rx_date,first_rx_date,tuner_key,fcc_key) values '; 
  # loop over json and append to $sql
  foreach my $frequency (keys %{$json->{signal}}) {
    $sql .= "('$json->{signal}{$frequency}{time}','$json->{signal}{$frequency}{time}','$json->{tuner_key}',";
    $sql .= <<"FCCSQL";
(select fcc_key from fm_fcc
  where pi_code = $json->{signal}{$frequency}{pi_code}
  and frequency = $frequency
  and st_distance_sphere(latlon, (SELECT latlon FROM fm_tuner WHERE tuner_key = '$json->{tuner_key}')) <=
     CASE
       WHEN MONTH(NOW()) IN (9, 10, 11, 12, 1, 2, 3) THEN 2414000
       ELSE 999999999
     END
  order by (
    st_distance_sphere(
      latlon,
      (select latlon from fm_tuner where tuner_key = $json->{tuner_key})
    )
  ) asc limit 1
)),
FCCSQL

  } 

  chop $sql;
  chop $sql;  # remove , from last row
  $sql .= <<'ODK';
 on duplicate key update
   rx_date = values(first_rx_date),
   first_rx_date = first_rx_date,
   tuner_key = values(tuner_key),
   fcc_key = values(fcc_key);
ODK

$c->log->debug($sql);
  try {
    $storage->dbh_do(sub {my ($s,$dbh,@args) =@_; my $sth = $dbh->prepare($sql); $sth->execute()});
  } catch {
    if (index($_,"Deadlock found") > -1) {
      $c->log->warn("DB deadlock detected for FM reception report, retrying.");
      sleep(int(rand(3)) + 1);
      $storage->dbh_do(sub {my ($s,$dbh,@args) =@_; my $sth = $dbh->prepare($sql); $sth->execute()});
    } else {
      $c->log->warn($_);
    }
  };

}

=head2 delete

Delete a spot from the database with http get.  Args are tuner_key, callsign
and frequency

=cut

sub delete :Global {
  my ( $self, $c, $tuner_key, $callsign, $frequency ) = @_;

  # errors if $tuner_key dosen't exist
  my $tuner = $self->_get_tuner($c,$tuner_key);
  my $rs = $c->model('DB::FmSignalReport')->search(
             {'tuner_key' => $tuner_key,
              'fcc_key.frequency' => $frequency,
              'fcc_key.callsign' => $callsign},
             {join => 'fcc_key'});
  if ($rs->count == 0) {
    $c->response->body('NOT FOUND');
    $c->response->status(404);
    return;
  }
  unless (_check_delete($c,$tuner,$tuner_key)) {
    $c->response->body("You don't have delete permissions for this location. Contact the administrator if you need it.");
    $c->response->status(401);
    return;
  }

  $rs->delete;
  $c->stash(tuner_key    => $tuner_key);
  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(template     => 'Root/fm_delete.tt');
  $c->stash(current_view => 'HTML');
}


=head2 fm_map_data

Arguments are tuner_key that sent the reception reports to fm_spot and a
string for time period; 'ever' gets all data ever, otherwise just the last
24 hours. Returns JSON data for display by page created by sub fm_one_tuner_map

=cut


sub fm_map_data :Global {
  my ($self, $c, $tuner_key, $period) = @_;

  my $tuner = $self->_get_tuner($c,$tuner_key);

  my $now = DateTime->now;

  my $rs;
  if (defined $period && $period eq 'ever') {
    $rs = $c->model('DB::FmSignalReport')->search({'tuner_key' => $tuner_key,
                                             'signal_key' => { '!=', undef}});
  }
  else {
    my $last_24_hr = $now->subtract(days => 1);

    # get a ResultSet of signals
    $rs = $c->model('DB::FmSignalReport')
             ->tuner_date_range($tuner_key,$last_24_hr,$now)
             ->most_recent;
  }

  # build data structure that will be sent out at JSON
  my @markers;

  while(my $signal = $rs->next) {
    next unless defined $signal->fcc_key;
    my %station;
    my $gc_tuner = Geo::Calc->new( lat => $tuner->latitude,
                                   lon => $tuner->longitude,
                                   units => 'mi');
    # Geo::Calc distance_to gives wrong distance!!
    my $gis = GIS::Distance->new('Vincenty');

    next unless ($signal->fcc_key->latitude && $signal->fcc_key->longitude);
    my $km = $gis->distance_metal($tuner->latitude,
                                  $tuner->longitude,
                                  $signal->fcc_key->latitude,
                                  $signal->fcc_key->longitude);
    $km = nearest(.1, $km); # to nearest 1/10 km
    my $azimuth = int($gc_tuner->bearing_to({lat => $signal->fcc_key->latitude,
                                       lon => $signal->fcc_key->longitude},
                                       -1));

    my $call = $signal->fcc_key->callsign;
    $station{callsign} = $call;  # can't use key 'call', it trashes javascript
    $station{strength} = $signal->strength;
    $station{latitude} = $signal->fcc_key->latitude+0;
    $station{longitude} = $signal->fcc_key->longitude+0;
    $station{frequency} = $signal->fcc_key->frequency;
    $station{city_state} = $signal->fcc_key->city_state;
    $station{erp_h} = ($signal->fcc_key->erp_h // 0)*1000;
    $station{erp_v} = ($signal->fcc_key->erp_v // 0)*1000;
    $station{haat_h} = ($signal->fcc_key->haat_h // 0)+0;
    $station{haat_v} = ($signal->fcc_key->haat_v // 0)+0;
    $station{last_in} = $signal->http_time;
    $station{color} = $signal->color;
    $station{azimuth} = $azimuth;
    $station{km} = $km;

    push @markers, \%station;
  }

  $c->stash('tuner_key' => $tuner_key);
  $c->stash('tuner_longitude' => $tuner->longitude+0);
  $c->stash('tuner_latitude' => $tuner->latitude+0);
  $c->stash('markers' => \@markers);
  $c->res->header('Access-Control-Allow-Origin'=>'https://www.rabbitears.info',
                  'Access-Control-Allow-Methods'=>'GET');
  $c->detach( $c->view('JSON') );
}


=head2 fm_one_tuner_map

Display a map for just one tuner.  Argument is tuner that sent the
reception reports to automated_spot

Loads basic map which then periodically uses javascript to get JSON data
from this program using sub fm_map_data.

Basic map has template to get tuner location, handle, etc.

=cut

sub fm_one_tuner_map :Global {
  my ($self, $c, $tuner_key) = @_;

  my $tuner = $self->_get_tuner($c,$tuner_key);

  if (_check_delete($c,$tuner,$tuner_key)) {
    $c->stash(delete_auth => 1);
  } else {
    $c->stash(delete_auth => 0);
  }

  $c->stash(tuner        => $tuner);
  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(static_url   => $c->config->{static_url});
  $c->stash(template     => 'Root/fm_one_tuner_map.tt');
  $c->stash(current_view => 'HTML');

  return;
}


# errors if $tuner_key dosen't exist or return result set
sub _get_tuner {
  my ($self,$c,$tuner_key) = @_;

  # error if tuner is not in d.b.
  unless (defined $tuner_key) {
    $c->response->body("FAIL: missing tuner_key");
    $c->response->status(403);
    $c->detach();
  }
  my $tuner = $c->model('DB::FmTuner')->find({'tuner_key'=>$tuner_key});
  if (! $tuner) {
    $c->response->body("FAIL: Tuner $tuner_key is not registered with site");
    $c->response->status(403);
    $c->detach();
  }
  return $tuner;
}

=head2 fm_all_tuner_data

JSON data for all stations received by anyone in the last 24 hours

=cut

sub fm_all_tuner_data :Global {
  my ($self, $c) = @_;

  my %json;
  $json{tuners} = { 'type' => 'FeatureCollection', 'features' => []};
  $json{stations} = { 'type' => 'FeatureCollection', 'features' => []};
  $json{paths} = { 'type' => 'FeatureCollection', 'features' => []};
  my %tuners;
  my %stations;

  my $rs;
  # get a ResultSet of signals
  $rs = $c->model('DB::FmSignalReport')->all_last_24();
  while(my $signal = $rs->next) {
    my $callsign = $signal->fcc_key->callsign;
    my $callsign_longitude = 0+$signal->fcc_key->longitude;
    my $callsign_latitude = 0+$signal->fcc_key->latitude;
    my $tuner_longitude = 0+$signal->tuner_key->longitude;
    my $tuner_latitude = 0+$signal->tuner_key->latitude;
    my $frequency = $signal->fcc_key->frequency;
    my $tuner_key = $signal->tuner_key->tuner_key;
    my $user_key = $signal->tuner_key->user_key;
    my $city_state = $signal->fcc_key->city_state;
    push @{$json{paths}{features}},
      { 'type' => "Feature",
        'geometry' => { 'type' => 'LineString',
                        'coordinates' => [[$callsign_longitude,
                                           $callsign_latitude],
                                          [$tuner_longitude,
                                           $tuner_latitude]]
                      },
        'properties' => { 'rx_date' => $signal->http_time,
                          'frequency' => $frequency,
                          'tuner_key' => $tuner_key,
                          'callsign' => $callsign,
                          'color' => $signal->color,
                          'description' => $user_key->description . " to $callsign ($city_state)",
                        }
      };

    # update %stations
    unless (exists $stations{$callsign}) {
      my $hh = $signal->fcc_key->haat_h // 0;
      my $hv = $signal->fcc_key->haat_v // 0;
      my $haat = $hh > $hv ? $hh : $hv;

      my $eh = $signal->fcc_key->erp_h // 0;
      my $ev = $signal->fcc_key->erp_v // 0;
      my $erp = $eh > $ev ? $eh : $ev;

      $stations{$callsign} = {
        frequency  => $frequency,
        longlat    => [$callsign_longitude, $callsign_latitude],
        city_state => $city_state,
        erp        => $erp,
        haat       => $haat,
      }
    }

    # update %tuners
    unless (exists $tuners{$tuner_key}) {
      my $description = $signal->tuner_key->user_key->description . ' ' 
                      . $signal->tuner_key->description;
      $tuners{$tuner_key}{descr} = $description;
      $tuners{$tuner_key}{longlat} = [$tuner_longitude,$tuner_latitude];
    }
  }

  # populate $json{tuners} from %tuners
  foreach my $tuner_key (keys %tuners) {
    push @{$json{tuners}{features}}, {
        'type' => "Feature",
        'geometry' => { 'type' => 'Point', 'coordinates' => $tuners{$tuner_key}{longlat} },
        'properties' => { 'description' => $tuners{$tuner_key}{descr},
                          'tuner_key' => $tuner_key }
    }
  }
  
  #populate $json{stations} from %stations
  while (my ($callsign,$fcc) = each %stations) {
    push @{$json{stations}{features}},
        { 'type' => "Feature",
          'geometry' => { 'type' => 'Point', 'coordinates' => $fcc->{longlat}},
          'properties' => { 'callsign'  => $callsign,
                            'frequency' => $fcc->{frequency},
                            'erp'       => $fcc->{erp},
                            'haat'      => $fcc->{haat}, }
        }
  }
  $c->stash('json' => \%json);
  $c->res->header('Access-Control-Allow-Origin'=>'https://www.rabbitears.info',
                  'Access-Control-Allow-Methods'=>'GET');
  $c->detach( $c->view('JSON') );
}


=head2 fm_all_tuners

Display map showing all tuners

=cut

sub fm_all_tuners :Global {
  my ($self, $c) = @_;

  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(static_url   => $c->config->{static_url});
  $c->stash(template     => 'Root/fm_all_tuners.tt');
  $c->stash(current_view => 'HTML');
}

# return 1 if delete is allowed, 0 if not
# tried to use Catalyst::Plugin::Authorization::Roles 
# check_any_user_role but couldn't get it to work
sub _check_delete {
  my ($c, $tuner, $tuner_key) = @_;

  if (defined $tuner->ipaddress && $tuner->ipaddress eq $c->request->address) {
    return 1;
  }
  return 0 unless $tuner_key && defined $c->user && $c->user->user_key;
  return 0 unless defined $c->user->permissions;
  my @permissions = split /\|/, $c->user->permissions;
  my $rs = $c->model('DB::FmTuner')->search({'user_key'=>$c->user->user_key});
  while (my $r = $rs->next) {
    if ($r->tuner_key == $tuner_key && any {$_ eq 'delete'} @permissions) {
      return 1;
    }
  }
  if (any { $_ eq $tuner_key } @permissions) {
    return 1;
  }
  return 0;
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2021 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
