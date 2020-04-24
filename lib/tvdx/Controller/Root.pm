package tvdx::Controller::Root;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::HTTP;
use XML::Simple;
use LWP::Simple;
use RRDs;
use List::MoreUtils 'none';
use Math::Round 'nearest';
# leaks memory, have to use Geo::Calc even though it's much slower
#use Geo::Calc::XS;
use Geo::Calc;
use GIS::Distance;
use GD;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in tvdx.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

tvdx::Controller::Root - Root Controller for tvdx

=head1 DESCRIPTION

Methods for automated TV propagation logging and map display

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body( "A map showing all locations is at http://www.rabbitears.info/all_tuners" );
    $c->response->status(202);
}

=head2 automated_spot

Called at end of scan in (client) scanlog.pl  Updates spot database with
most recent TV callsigns received, strengths, spotter's ID, etc.

=cut

sub automated_spot :Global {
  my ( $self, $c ) = @_;


  # the current time formatted to mysql format (UTC time zone)
  my $mysql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);
  my $now_epoch = time;

  # xml with information from (client) scanlog.pl
  my $href = XMLin($c->request->params->{'xml'}, ForceArray => ['tv_signal'] );

  my $entry = 0;

  my ($junk,$tuner_id,$tuner_number) = split /_/, $href->{'user_id'};

  # log if tuner isn't found
  if (! $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id})) {
    open L, ">>/tmp/unknown_tuner" or return 0;
    print L "$mysql_now: tuner_id $tuner_id not found in tuner table\n";
    close L;
    $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
    $c->response->status(403);
    return;
  }

  TVSPOT: foreach my $tv_signal (@{$href->{'tv_signal'}}) {
    my $channel         = $tv_signal->{'rf_channel'};
    $channel =~ s/\D//g;
    my $callsign        = $tv_signal->{'callsign'};
    my $virtual_channel = $tv_signal->{'virtual_channel'};
    # fcc table needs a real number for virtual_chanel
    if ($virtual_channel !~ /^\d+\.{0,1}\d*$/) { $virtual_channel = '0.0'; }

    # WPXR has PSID WCW5, which winds up as WCW here.  Change it to what
    # it should be
    if ($callsign eq 'WCW' and $virtual_channel eq '27.2') {
      $callsign = 'WFXR';
    }

    # add or update fcc table if needed
    if (! $self->_call_current($c,$callsign,$channel,$virtual_channel)) {
      next TVSPOT;
    }

    my $spot = {
      'rx_date'         => $mysql_now,
      'rf_channel'      => $channel,
      'strength'        => $tv_signal->{'strength'},
      'sig_noise'       => $tv_signal->{'sig_noise'},
      'tuner_id'        => $tuner_id,
      'tuner_number'    => $tuner_number,
      'callsign'        => $callsign,
      'virtual_channel' => $virtual_channel, };

    next TVSPOT if ( ! _spot_data_ok($spot) );

    # create new record if needed.  Station moving to new channel qualifies
    $entry = $c->model('DB::SignalReport')
               ->find({'tuner_id' => $tuner_id,
                       'tuner_number' => $tuner_number,
                       'callsign' => $callsign,});
    if (! $entry) {
      $spot->{'first_rx_date'} = $mysql_now;
      $entry = $c->model('DB::SignalReport')->create($spot);
      last TVSPOT if (! $entry);
    }
    $entry->update({'rx_date'    => $mysql_now,
                    'rf_channel' => $channel,
                    'strength'   => $tv_signal->{'strength'},
                    'sig_noise'  => $tv_signal->{'sig_noise'}});

    my $rrd_file = join '_', ($tuner_id,$tuner_number,$callsign);
    $rrd_file = $c->config->{rrd_dir} . "/$rrd_file.rrd";

    if ( _rrd_not_pending($rrd_file) && ! -r $rrd_file ) {
      RRDs::create( $rrd_file, '--start', '-6hours', '--step', '60',
                    "DS:strength:GAUGE:300:0:100",
                    "DS:sig_noise:GAUGE:300:0:100",
                    "RRA:MAX:.99:1:288000",
                    "RRA:MAX:.99:60:131040" );
      # short duration DX won't have a graph point unless it's stretched out
      for (my $i = 3; $i > 0; $i--) {
        my $te = $now_epoch - 60*$i;
        RRDs::update( $rrd_file, '--daemon', $c->config->{socket},
                      '--template', 'strength:sig_noise',
                      "$te:$tv_signal->{strength}:$tv_signal->{sig_noise}");
      }
    }

    if (_rrd_not_pending($rrd_file) && $now_epoch-600 > RRDs::last($rrd_file)) {
      for (my $i = 3; $i > 0; $i--) {
        my $te = $now_epoch - 60*$i;
        RRDs::update( $rrd_file, '--daemon', $c->config->{socket},
                      '--template', 'strength:sig_noise',
                      "$te:$tv_signal->{strength}:$tv_signal->{sig_noise}");
      }
    } 

    RRDs::update( $rrd_file, '--daemon', $c->config->{socket},
                  '--template', 'strength:sig_noise',
                  "$now_epoch:$tv_signal->{strength}:$tv_signal->{sig_noise}");
  }

  if (! $entry) {
    $c->response->body("FAIL: ", @{$c->error});
    $c->response->status(400);
  }
  else {
    $c->response->body('OK');
    $c->response->status(202);
  }
}


sub _spot_data_ok {
  my ($spot) = @_;

  # not an int?
  return 0 if $spot->{'rf_channel'} - int $spot->{'rf_channel'} > 0;
  return 0 if $spot->{'rf_channel'} =~ /\D/;
  # invalid number?
  return 0 if $spot->{'rf_channel'} > 69;
  return 0 if $spot->{'rf_channel'} < 2;

  foreach ($spot->{'strength'},$spot->{'sig_noise'}) {
    # not an int?
    return 0 if $_ - int $_ > 0;
    return 0 if $_ =~ /\D/;
    # invalid number?
    return 0 if $_ > 100;
    return 0 if $_ < 0;
  }

  # unresolveable call in FCC database?  WWPX2 is an alias for
  # WWPX repeater in DC on same channel, KRMA47 is repeater also
  if (   ($spot->{'callsign'} ne 'WWPX2') && ($spot->{'callsign'} ne 'KRMA47')
      && ($spot->{'callsign'} !~ /^[CWKX](\d\d)*[A-Z]{2,3}$/)) {
    return 0;
  }

  return 0 if $spot->{'virtual_channel'} !~ /^\d+\.{0,1}\d*$/;

  return 1;
}


sub _rrd_not_pending {
  my ($rrd) = @_;

  $tvdx::socket_io->send("PENDING $rrd\n");
  my $response;
  $tvdx::socket_io->recv($response, 16384);
  my ($status) = split /\s/, $response;

  return $status > 0 ? 0 : 1;
}


# Check or update (if > 1 day old) or create call sign in fcc table
# Returns 1 on success, 0 on failure.
sub _call_current {
  my ( $self,$c,$p_callsign,$channel,$virtual_channel ) = @_;

  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  my ($fcc_call) = $c->model('DB::Fcc')->find({'callsign' => $p_callsign});

  # Make sure FCC data is current
  if ((! $fcc_call) || (DateTime::Format::MySQL->parse_datetime($fcc_call->last_fcc_lookup) < $yesterday)) {
    my $tvq = get("http://www.rabbitears.info/rawlookup.php?call=$p_callsign");
    # get returns undef if it can't get data
    return 0 if ! defined $tvq;

    my ($call,$fcc_channel,
        $city,$state,
        $rcamsl,$erp,
        $n_or_s,$lat_deg,$lat_min,$lat_sec,
        $w_or_e,$lon_deg,$lon_min,$lon_sec,
        $digital_tsid,$analog_tsid,$observed_tsid) = split /\s*\|/,$tvq;

    # FCC channel match must be exact
    return 0 if $fcc_channel != $channel;

    # remove any suffix from end
    $call =~ s/\-.*//;

    # add units to height
    $rcamsl = "$rcamsl m";
    # add units to power
    $erp = "$erp kW";
    my $location = "$city, $state";

    my $lat_decimal = $lat_deg + $lat_min/60 + $lat_sec/3600;
    $lat_decimal = -1 * $lat_decimal if ($n_or_s eq 'S' || $n_or_s eq '-');

    my $lon_decimal = $lon_deg + $lon_min/60 + $lon_sec/3600;
    $lon_decimal = -1 * $lon_decimal if ($w_or_e eq 'W' || $w_or_e eq '-');

    # the current time formatted to mysql format (UTC time zone)
    my $mysql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);

    # all-new call sign?
    if (! $fcc_call) {
      $c->model('DB::Fcc')->create({
        'callsign'        => $p_callsign,
        'rf_channel'      => $fcc_channel,
        'latitude'        => $lat_decimal,
        'longitude'       => $lon_decimal,
        'start_date'      => $mysql_now,
        'virtual_channel' => $virtual_channel,
        'city_state'      => $location,
        'erp_kw'          => $erp,
        'rcamsl'          => $rcamsl,
        'last_fcc_lookup' => $mysql_now, });
      return 1;
    }
    # else just update
    else {
      $fcc_call->update({
        'rf_channel'      => $fcc_channel,
        'latitude'        => $lat_decimal,
        'longitude'       => $lon_decimal,
        'virtual_channel' => $virtual_channel,
        'city_state'      => $location,
        'erp_kw'          => $erp,
        'rcamsl'          => $rcamsl,
        'last_fcc_lookup' => $mysql_now, });
      return 1;
    }
  }
  return 1; # last_fcc_lookup is not very old, don't bother with FCC site.
}


=head2 many_tuner_map

Display a map for multiple tuners.  Arguments are tuners that sent the
reception reports to automated_spot

Loads basic map which then periodically uses javascript to get JSON data
from this program using sub tuner_map_data for each tuner.

Basic map has template to get tuner locations, handles, etc.

=cut

sub many_tuner_map :Global {
  my ($self, $c, @tuner_info) = @_;

  my @reception_locations;

  $self->_check_tuners($c,@tuner_info);

  my @tuner_info_copy = @tuner_info;
  while (@tuner_info_copy) {
    my $tuner_id =     shift @tuner_info_copy;
    my $tuner_number = shift @tuner_info_copy; 

    my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
    my $tn =$c->model('DB::TunerNumber')->find({'tuner_id'=>$tuner_id,
                                                'tuner_number'=>$tuner_number});
    push @reception_locations,   $tuner->owner_id
                               . " "
                               . $tn->description
                               . '<p><a href="' 
                               . $c->config->{root_url}
                               . "/one_tuner_map/$tuner_id/$tuner_number"
                               . '">map for just this location</a>';
  }

  $c->stash(tuner_info          => \@tuner_info);
  $c->stash(reception_locations => \@reception_locations);
  $c->stash(static_url          => $c->config->{static_url});
  $c->stash(root_url            => $c->config->{root_url});
  $c->stash(gmap_key            => $c->config->{gmap_key});
  $c->stash(template            => 'Root/many_tuner_map.tt');
  $c->stash(current_view        => 'HTML');

  return;
}


=head2 one_tuner_map

Display a map for just one tuner.  Argument is tuner that sent the
reception reports to automated_spot

Loads basic map which then periodically uses javascript to get JSON data
from this program using sub tuner_map_data.

Basic map has template to get tuner location, handle, etc.

=cut

sub one_tuner_map :Global {
  my ($self, $c, $tuner_id, $tuner_number) = @_;

  # check if tuner is known
  $self->_check_tuners($c,$tuner_id, $tuner_number);

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
  my $tn = $c->model('DB::TunerNumber')->find({'tuner_id'=>$tuner_id,
                                               'tuner_number'=>$tuner_number});

  $c->stash(tuner        => $tuner);
  $c->stash(tuner_number => $tn);
  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(static_url   => $c->config->{static_url});
  $c->stash(gmap_key     => $c->config->{gmap_key});
  $c->stash(template     => 'Root/one_tuner_map.tt');
  $c->stash(current_view => 'HTML');

  return;
}


=head2 tuner_map_data

Arguments are tuner_id and tuner_number that sent the reception reports
to automated_spot and a string for time period; 'ever' gets all data
ever, otherwise just the last 24 hours.
Returns JSON data for display by page created by sub one_tuner_map

=cut

sub tuner_map_data :Global {
  my ($self, $c, $tuner_id, $tuner_number, $period) = @_;

  # check if tuner is known
  $self->_check_tuners($c,$tuner_id,$tuner_number);

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});

  my $rs;
  if (defined $period && $period eq 'ever') {
    $rs = $c->model('DB::SignalReport')->search({'tuner_id' => $tuner_id,
                                           'tuner_number' => $tuner_number,
                                           'callsign' => { '!=', undef}});
  }
  else {
    my $now = DateTime->now;
    my $last_24_hr = DateTime->from_epoch( epoch => time-86400 );

    # get a ResultSet of signals
    $rs = $c->model('DB::SignalReport')
             ->tuner_date_range($tuner_id,$tuner_number,$last_24_hr,$now)
             ->most_recent;
  }

  # build data structure that will be sent out at JSON
  my @markers;

  while(my $signal = $rs->next) {
    next unless defined $signal->callsign;
    my %station;
    my $gc_tuner = Geo::Calc->new( lat => $tuner->latitude,
                                   lon => $tuner->longitude,
                                   units => 'mi');
    # Geo::Calc distance_to gives wrong distance!!
    my $gis = GIS::Distance->new(); 
    $gis->formula('Vincenty');
    next unless ($signal->callsign->latitude && $signal->callsign->longitude);
    my $miles = $gis->distance($tuner->latitude,
                               $tuner->longitude =>
                               $signal->callsign->latitude,
                               $signal->callsign->longitude)->miles();
    $miles = nearest(.1, $miles); # to nearest 1/10 of mile
    my $azimuth = int($gc_tuner->bearing_to({lat => $signal->callsign->latitude,                                        lon => $signal->callsign->longitude},
                                       -1));

    my $sdt = DateTime::Format::MySQL->parse_datetime($signal->rx_date);

    my $call = $signal->callsign->callsign;
    $station{callsign} = $call;  # can't use key 'call', it trashes javascript
    $station{strength} = $signal->strength;
    $station{sig_noise} = $signal->sig_noise;
    $station{color} = $signal->color;
    $station{latitude} = $signal->callsign->latitude;
    $station{longitude} = $signal->callsign->longitude;
    $station{rf_channel} = $signal->callsign->rf_channel;
    $station{virtual_channel} =$signal->callsign->virtual_channel;
    $station{city_state} = $signal->callsign->city_state;
    $station{erp} = $signal->callsign->erp_kw;
    $station{rcamsl} = $signal->callsign->rcamsl;
    $station{last_in} = DateTime::Format::HTTP->format_datetime($sdt);
    $station{azimuth} = $azimuth;
    $station{miles} = $miles;

    $station{graphs_url} =
      $c->config->{root_url}."/signal_graph/$tuner_id/$tuner_number/$call";

    # create Callsign icon if it doesn't exist yet
    my $png = $c->config->{image_dir} . "/$call.png";
    if (! -r $png) {
      if (! _icon_png($call,'white',$png)) {
        $c->response->body("FAIL: Can't create $call.png");
        $c->response->status(403);
        return 0;
      }
    }

    push @markers, \%station;
  }

  $c->stash('tuner_id' => $tuner_id);
  $c->stash('tuner_number' => $tuner_number);
  $c->stash('tuner_longitude' => $tuner->longitude);
  $c->stash('tuner_latitude' => $tuner->latitude);
  $c->stash('markers' => \@markers);
  $c->res->header('Access-Control-Allow-Origin'=>'https://www.rabbitears.info',
                  'Access-Control-Allow-Methods'=>'GET');
  $c->detach( $c->view('JSON') );
}


=head2 all_tuners

Replacement for all_tuner_map.  Much quicker and more functional

=cut

sub all_tuners :Global {
  my ($self, $c) = @_;

  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(static_url   => $c->config->{static_url});
  $c->stash(template     => 'Root/all_tuners.tt');
  $c->stash(current_view => 'HTML');
}


=head2 all_tuner_data

JSON data for all stations received by anyone in the last 24 hours

=cut

sub all_tuner_data :Global {
  my ($self, $c) = @_;

  my %json;
  $json{tuners} = { 'type' => 'FeatureCollection', 'features' => []};
  $json{stations} = { 'type' => 'FeatureCollection', 'features' => []};
  $json{paths} = { 'type' => 'FeatureCollection', 'features' => []};
  my %tuners;
  my %stations;

  my $rs;
  # get a ResultSet of signals
  $rs = $c->model('DB::SignalReport')->all_last_24();
  while(my $signal = $rs->next) {
    my $callsign = $signal->callsign->callsign;
    # 0+ to force to a number.  Don't know why accessor returns a string.
    my $callsign_longitude = 0+$signal->callsign->longitude;
    my $callsign_latitude = 0+$signal->callsign->latitude;
    my $tuner_longitude = 0+$signal->tuner->longitude;
    my $tuner_latitude = 0+$signal->tuner->latitude;
    my $rf_channel = 0+$signal->rf_channel;
    my $tuner_id = $signal->tuner_id;
    my $tuner_number = $signal->tuner_number;
    my $virtual_channel = $signal->virtual_channel;
    $virtual_channel = defined $virtual_channel ? int $virtual_channel : 0;
    my $owner_id = $signal->tuner->owner_id;
    my $city_state = $signal->callsign->city_state;
    push @{$json{paths}{features}},
      { 'type' => "Feature",
        'geometry' => { 'type' => 'LineString',
                        'coordinates' => [[$callsign_longitude,
                                           $callsign_latitude],
                                          [$tuner_longitude,
                                           $tuner_latitude]]
                      },
        'properties' => { 'rx_date' => DateTime::Format::HTTP->format_datetime(DateTime::Format::MySQL->parse_datetime($signal->rx_date)),
                          'rf_channel' => $rf_channel,
                          'strength' => 0+$signal->strength,
                          'sig_noise' => 0+$signal->sig_noise,
                          'tuner_id' => $tuner_id,
                          'tuner_number' => $tuner_number,
                          'callsign' => $callsign,
                          'virtual_channel' => $virtual_channel,
                          'color' => $signal->color,
                          'description' => "$owner_id to $callsign ($city_state)",
                        }
      };

    # update %stations
    unless (exists $stations{$callsign}) {
      # remove ' m' from rcamsl and make it a number
      my $rcamsl = $signal->callsign->rcamsl;
      chop $rcamsl; chop $rcamsl;
      $rcamsl = 0+$rcamsl;

      $stations{$callsign} = {
        rf_channel       => $rf_channel,
        longlat          => [$callsign_longitude, $callsign_latitude],
        virtual_channel  => $virtual_channel,
        city_state       => $city_state,
        erp_kw           => $signal->callsign->erp_kw,
        rcamsl           => $rcamsl,
      }
    }

    # update %tuners if necessary
    unless (exists $tuners{$tuner_id}
            && exists $tuners{$tuner_id}{$tuner_number}) {
      $tuners{$tuner_id}{$tuner_number} = {};
      my $tn =$c->model('DB::TunerNumber')
                ->find({'tuner_id'=>$tuner_id,
                        'tuner_number'=>$tuner_number});
      my $t = $c->model('DB::Tuner')->find({'tuner_id' => $tuner_id});
      $tuners{$tuner_id}{$tuner_number}{descr} =
        $t->owner_id . ' ' . $tn->description;
      $tuners{$tuner_id}{$tuner_number}{longlat} =
        [$tuner_longitude,$tuner_latitude];
    }
  }
  
  # populate $json{tuners} from %tuners
  while (my ($tuner_id_key,$tuner_id_value) = each %tuners) {
    while (my ($tuner_number_key,$tuner_number_value) = each %$tuner_id_value) {
      push @{$json{tuners}{features}},
        { 'type' => "Feature",
          'geometry' => { 'type' => 'Point', 'coordinates' => $tuner_number_value->{longlat}},
          'properties' => { 'description' => $tuner_number_value->{descr},
                            'url_path' => "$tuner_id_key/$tuner_number_key" }
        }
    }
  }

  #populate $json{stations} from %stations
  while (my ($callsign,$fcc) = each %stations) {
    push @{$json{stations}{features}},
        { 'type' => "Feature",
          'geometry' => { 'type' => 'Point', 'coordinates' => $fcc->{longlat}},
          'properties' => { 'callsign'        => $callsign,
                            'rf_channel'      => $fcc->{rf_channel},
                            'virtual_channel' => $fcc->{virtual_channel},
                            'erp_kw'          => $fcc->{erp_kw},
                            'rcamsl'          => $fcc->{rcamsl}, }
        }
  }
  $c->stash('json' => \%json);
  $c->res->header('Access-Control-Allow-Origin'=>'https://www.rabbitears.info',
                  'Access-Control-Allow-Methods'=>'GET');
  $c->detach( $c->view('JSON') );
}


=head2 signal_graph

Graphs for historic signal strength and Signal/noise for a station and tuner_id

=cut

sub signal_graph  :Global {
  my ($self, $c, $tuner_id, $tuner_number, $callsign) = @_;

  # check if tuner is known
  $self->_check_tuners($c,$tuner_id,$tuner_number);

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
  my $tn = $c->model('DB::TunerNumber')->find({'tuner_id'=>$tuner_id,
                                               'tuner_number'=>$tuner_number});

  my $entry = $c->model('DB::SignalReport')
                ->find({'tuner_id' => $tuner_id,
                        'tuner_number' => $tuner_number,
                        'callsign' => $callsign,});
  if (! $entry) {
    $c->response->body( "No reception reports for $callsign from $tuner_id $tuner_number" );
    $c->response->status(404);
    return;
  }
 
  $c->stash(tuner        => $tuner);
  $c->stash(tuner_number => $tn);
  $c->stash(callsign     => $callsign);
  $c->stash(static_url   => $c->config->{static_url});
  $c->stash(root_url     => $c->config->{root_url});
  $c->stash(template     => 'Root/signal_graph.tt');
  $c->stash(current_view => 'HTML');
}


=head2 render_graph

Renders a graph of signal strength and signal/noise for the given tuner,
callsign and/or channel and date range

=cut

sub render_graph :Global {
  my ($self,$c,
      $tuner_id,$tuner_number,
      $callsign,$start_time,$end_time,$height,$width) = @_;

  # set defaults if args are missing
  $start_time = $start_time ? $start_time : '-6hours';
  $end_time = $end_time ? $end_time : 'now';
  $height = $height ? $height : 300;
  $width = $width ? $width : 600;

  my $arg_is_callsign;
  my $rf_channel;
  # channel number instead of callsign as argument?
  if ($callsign =~ /^\d+$/) {
    $rf_channel = $callsign;
    $arg_is_callsign = 0;
  }
  else {
    # find RF channel number
    my $res = $c->model('DB::Fcc')->find({'callsign' => $callsign});
    return unless $res;
    $rf_channel = $res->rf_channel;
    $arg_is_callsign = 1;
  }

  my $channel_rrd_file = join '_', ($tuner_id,$tuner_number,$rf_channel);
  $channel_rrd_file = $c->config->{rrd_dir} . "/$channel_rrd_file.rrd";
  my $call_rrd_file = join '_', ($tuner_id,$tuner_number,$callsign);
  $call_rrd_file = $c->config->{rrd_dir} . "/$call_rrd_file.rrd";

  my $is_channel_rrd = -e $channel_rrd_file ?  1 : 0;

  if ($arg_is_callsign && $is_channel_rrd) {
    # generate graph with both channel and call signal strength/quality
    $c->stash->{'graph'} = [
      '--daemon', $c->config->{socket},
      '--lower-limit', '0', '--upper-limit', '100', '--rigid',
      '--start', $start_time,
      '--end', $end_time,
      '--vertical-label', 'Relative Quality',
      '--height', $height,
      '--width', $width,
      "DEF:call_raw_strength=$call_rrd_file:strength:MAX",
      "DEF:call_raw_sig_noise=$call_rrd_file:sig_noise:MAX",
      "DEF:ch_raw_strength=$channel_rrd_file:strength:MAX",
      "DEF:ch_raw_sig_noise=$channel_rrd_file:sig_noise:MAX",
      # change undefined values to zero
      'CDEF:call_strength=call_raw_strength,UN,0,call_raw_strength,IF',
      'CDEF:call_sig_noise=call_raw_sig_noise,UN,0,call_raw_sig_noise,IF',
      'CDEF:ch_strength=ch_raw_strength,UN,0,ch_raw_strength,IF',
      # zero out ch_sig_noise if there's call data or if it's NaN
      'CDEF:is_call_data=call_raw_sig_noise,UN,0,1,IF',
      'CDEF:ch_sig_noise_nan=ch_raw_sig_noise,UN',
      'CDEF:ch_sig_noise=is_call_data,ch_sig_noise_nan,+,0,ch_raw_sig_noise,IF',
      # plot the non-decodeable (RF channel)
      'AREA:ch_strength#7FFF00:Relative Strength (undecodeable signal)',
      'AREA:ch_sig_noise#FA0000:Relative Signal/Noise (undecodeable signal)',
      'AREA:call_strength#006400:Relative Strength  (decodeable signal)',
      'LINE:call_sig_noise#00008B:Relative Signal/Noise (decodeable signal)' ];
  }
  else {
    # just a callsign or channel number, not both
    $c->stash->{'graph'} = [
      '--daemon', $c->config->{socket},
      '--lower-limit', '0', '--upper-limit', '100', '--rigid',
      '--start', $start_time,
      '--end', $end_time,
      '--vertical-label', 'Relative Quality',
      '--height', $height,
      '--width', $width,
      "DEF:raw_strength=$call_rrd_file:strength:MAX",
      "DEF:raw_sig_noise=$call_rrd_file:sig_noise:MAX",
      # change undefined values to zero
      'CDEF:strength=raw_strength,UN,0,raw_strength,IF',
      'CDEF:sig_noise=raw_sig_noise,UN,0,raw_sig_noise,IF',
      'LINE:strength#00FF00:Relative Strength',
      'LINE:sig_noise#0000FF:Relative Signal/Noise' ];
  }
  # remove legend and vertical label if the graph is small
  splice @{$c->stash->{'graph'}}, 9, 2, '--no-legend' if ($width < 250);
  $c->detach( $c->view('RRDGraph') );
  return;
}


=head2 tuner_location_data

Retrieve the latitude and longitude for a tuner

=cut

sub tuner_location_data :Global {
  my ($self, $c, $tuner_id) = @_;

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
  $c->stash('tuner_latitude'  => $tuner->latitude);
  $c->stash('tuner_longitude' => $tuner->longitude);
  $c->res->header('Access-Control-Allow-Origin'=>'https://www.rabbitears.info',
                  'Access-Control-Allow-Methods'=>'GET');
  $c->detach( $c->view('JSON') );
}


=head2 all_stations_ever_map

Creates map of all stations ever received for one or more tuner.
javascript in template calls all_stations_data to populate map.

=cut

sub all_stations_ever_map :Global {
  my ($self, $c, @tuner_info) = @_;

  $self->_check_tuners($c,@tuner_info);
  
  my @reception_locations;

  my @tuner_info_copy = @tuner_info;
  while (@tuner_info_copy) {
    my $tuner_id =     shift @tuner_info_copy;
    my $tuner_number = shift @tuner_info_copy; 
    my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
    my $tn= $c->model('DB::TunerNumber')->find({'tuner_id'=>$tuner_id,
                                                'tuner_number'=>$tuner_number});
    push @reception_locations, $tuner->owner_id . " " . $tn->description;
  }


  $c->stash(tuner_info          => \@tuner_info);
  $c->stash(reception_locations => \@reception_locations);
  $c->stash(root_url            => $c->config->{root_url});
  $c->stash(static_url          => $c->config->{static_url});
  $c->stash(template            => 'Root/all_signals_ever_map.tt');
  $c->stash(current_view        => 'HTML');
}


=head2 is_ota

Body has the number of signal reports of a callsign for the number
of minutes requested.  Returns HTTP code 201 if 0, otherwise 200.
Optionally include a tuner id and number to narrow query.

=cut

sub is_ota :Global {
  my ($self,$c,$call,$minutes,$tuner_id,$tuner_number) = @_;

  if ($minutes =~ /\D+/) {
    $c->response->body("FAIL: invalid minutes argument");
    $c->response->status(400);
    return;
  }
  unless ($call) {
      $c->response->body("FAIL: invalid callsign argument");
      $c->response->status(400);
      return;
  }
  $minutes = 5 if $minutes eq '';

  my $start = DateTime::Format::MySQL->format_datetime(
    DateTime->from_epoch(epoch => time-$minutes*60));

  my %q = (callsign => $call, rx_date => { '>=' => $start });
  $q{tuner_id} = $tuner_id if $tuner_id;
  $q{tuner_number} = $tuner_number if $tuner_number;

  my $count = $c->model('DB::SignalReport')->count(%q);

  $c->response->body($count);
  $c->response->status($count > 0 ? 200 : 201)
}


# if any tuner is unknown, send back an error message
sub _check_tuners {
  my ($self,$c,@check_tuner_info) = @_;

  while (@check_tuner_info) {
    my $tuner_id =     shift @check_tuner_info;
    my $tuner_number = shift @check_tuner_info; 

    unless (defined $tuner_id) {
      $c->response->body("FAIL: missing tuner id");
      $c->response->status(403);
      $c->detach();
    }
    unless (defined $tuner_id) {
      $c->response->body("FAIL: missing tuner number");
      $c->response->status(403);
      $c->detach();
    }

    if (! $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id})) {
      $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
      $c->response->status(403);
      $c->detach();
    }
    if (! $c->model('DB::TunerNumber')->find({'tuner_number'=>$tuner_number,
                                              'tuner_id'=>$tuner_id})) {
      $c->response->body("FAIL: Tuner $tuner_id tuner number $tuner_number is not registered with site");
      $c->response->status(403);
      $c->detach();
    }
  }
}


# create a rectangle filled with $background_color contaning $text
sub _icon_png {
  my ($text,$background_color,$out_file) = @_;

  # create a new image
  my $width = 2 + length($text) * 5;
  my $im = new GD::Image($width,9);

  # allocate some colors
  my $white = $im->colorAllocate(255,255,255);
  my $black = $im->colorAllocate(0,0,0);
  my $red = $im->colorAllocate(255,0,0);
  my $yellow = $im->colorAllocate(255,255,0);
  my $green = $im->colorAllocate(0,0,255);

  my %color_for = ( 'white' => $white,
                    'black' => $black,
                    'red'   => $red,
                    'yellow'=> $yellow,
                    'green' => $green, );

  # fill with background color
  $im->fillToBorder(5,5,$color_for{$background_color},$white);

  # write text
  $im->string(gdTinyFont,1,1,$text,$black);

  open ICON, "> $out_file" or return 0;
  print ICON $im->png;
  close ICON;

  return 1;
}


=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Russell J Dwarshuis, KB8U

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
