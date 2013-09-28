package tvdx::Controller::Root;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::SQLite;
use DateTime::Format::HTTP;
use XML::Simple;
use LWP::Simple;
use RRDs;
use List::MoreUtils 'none';
# leaks memory, have to use Geo::Calc even though it's much slower
#use Geo::Calc::XS;
use Geo::Calc;
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


  # the current time formatted to sqlite format (UTC time zone)
  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $now_epoch = time;

  # xml with information from (client) scanlog.pl
  my $href = XMLin($c->request->params->{'xml'}, ForceArray => ['tv_signal'] );

  my $entry = 0;

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
      'rx_date'         => $sqlite_now,
      'rf_channel'      => $channel,
      'strength'        => $tv_signal->{'strength'},
      'sig_noise'       => $tv_signal->{'sig_noise'},
      'tuner_id'        => $tuner_id,
      'tuner_number'    => $tuner_number,
      'callsign'        => $callsign,
      'virtual_channel' => $virtual_channel, };

    next TVSPOT if ( ! _spot_data_ok($spot) );

    # create new record if needed.  Station moving to new channel qualifies
    $entry = $c->model('DB::Signal')
               ->find({'tuner_id' => $tuner_id,
                       'tuner_number' => $tuner_number,
                       'callsign' => $callsign,});
    if (! $entry) {
      $spot->{'first_rx_date'} = $sqlite_now;
      $entry = $c->model('DB::Signal')->create($spot);
      last TVSPOT if (! $entry);
    }
    $entry->update({'rx_date'    => $sqlite_now,
                    'rf_channel' => $channel,
                    'strength'   => $tv_signal->{'strength'},
                    'sig_noise'  => $tv_signal->{'sig_noise'}});

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
        RRDs::update( $rrd_file, '--template', 'strength:sig_noise',
                      "$te:$tv_signal->{strength}:$tv_signal->{sig_noise}");
      }
    }

    if ($now_epoch-600 > RRDs::last($rrd_file)) {
      for (my $i = 3; $i > 0; $i--) {
        my $te = $now_epoch - 60*$i;
        RRDs::update( $rrd_file, '--template', 'strength:sig_noise',
                      "$te:$tv_signal->{strength}:$tv_signal->{sig_noise}");
      }
    } 

    RRDs::update( $rrd_file, '--template', 'strength:sig_noise',
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


# Check or update (if > 1 day old) or create call sign in fcc table
# Returns 1 on success, 0 on failure.
sub _call_current {
  my ( $self,$c,$p_callsign,$channel,$virtual_channel ) = @_;

  my $yesterday = DateTime->from_epoch( 'epoch' => (time() - 86400) );

  my ($fcc_call) = $c->model('DB::Fcc')->find({'callsign' => $p_callsign});

  # Make sure FCC data is current
  if ((! $fcc_call) || (DateTime::Format::SQLite->parse_datetime($fcc_call->last_fcc_lookup) < $yesterday)) {
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
    $lat_decimal = -1 * $lat_decimal if $n_or_s eq 'S';

    my $lon_decimal = $lon_deg + $lon_min/60 + $lon_sec/3600;
    $lon_decimal = -1 * $lon_decimal if $w_or_e eq 'W';

    # the current time formatted to sqlite format (UTC time zone)
    my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);

    # all-new call sign?
    if (! $fcc_call) {
      $c->model('DB::Fcc')->create({
        'callsign'        => $p_callsign,
        'rf_channel'      => $fcc_channel,
        'latitude'        => $lat_decimal,
        'longitude'       => $lon_decimal,
        'start_date'      => $sqlite_now,
        'virtual_channel' => $virtual_channel,
        'city_state'      => $location,
        'erp_kw'          => $erp,
        'rcamsl'          => $rcamsl,
        'last_fcc_lookup' => $sqlite_now, });
      return 1;
    }
### BUG: FCC could return new location, need to update end and create
### new record in that case.  DB needs to be changed to two primary keys???
    # else just update
    else {
      $fcc_call->update({'last_fcc_lookup' => $sqlite_now, });
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
  $c->stash(template     => 'Root/one_tuner_map.tt');
  $c->stash(current_view => 'HTML');

  return;
}


=head2 tuner_map_data

Argument is tuner_id that sent the reception reports to automated_spot.
Returns JSON data for display by page created by sub one_tuner_map

=cut

sub tuner_map_data :Global {
  my ($self, $c, $tuner_id, $tuner_number) = @_;

  # check if tuner is known
  $self->_check_tuners($c,$tuner_id,$tuner_number);

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});

  my $now = DateTime->now;

  my $last_5_min = DateTime->from_epoch( epoch => time-300 );
  my $last_24_hr = DateTime->from_epoch( epoch => time-86400 );

  # get a ResultSet of signals
  my $rs = $c->model('DB::Signal')
             ->tuner_date_range($tuner_id,$tuner_number,$last_24_hr,$now)
             ->most_recent;

  # build data structure that will be sent out at JSON
  my (@black_markers,@red_markers,@yellow_markers,@green_markers);

  while(my $signal = $rs->next) {
    my $gc_tuner = Geo::Calc->new( lat => $tuner->latitude,
                                   lon => $tuner->longitude,
                                   units => 'mi');
    my $miles = $gc_tuner->distance_to({lat => $signal->callsign->latitude,
                                        lon => $signal->callsign->longitude},
                                       -1);
    my $azimuth = int($gc_tuner->bearing_to({lat => $signal->callsign->latitude,                                        lon => $signal->callsign->longitude},
                                       -1));
    my %station;

    my $sdt = DateTime::Format::SQLite->parse_datetime($signal->rx_date);
    # spot up to 5 minutes old get color icons
    my $color = ($sdt >= $last_5_min) ? $signal->color : 'black';

    my $call = $signal->callsign->callsign;
    $station{callsign} = $call;  # can't use key of call, it trashes javascript
    $station{latitude} = $signal->callsign->latitude;
    $station{longitude} = $signal->callsign->longitude;
    $station{info} = 
             '<br>RF channel ' . $signal->callsign->rf_channel . '<br>'
           . 'Virtual channel ' . $signal->callsign->virtual_channel . '<br>'
           . $signal->callsign->city_state . '<br>'
           . 'ERP ' . $signal->callsign->erp_kw .'<br>'
           . 'RCAMSL ' . $signal->callsign->rcamsl . '<br>';
    if ($color eq 'black') {
      my $dtf_http = 'DateTime::Format::HTTP';
      $station{last_in} = 'last in '. $dtf_http->format_datetime($sdt) . '<br>';
    }
    else { $station{last_in} = ''; }

    $station{azimuth_dx} = "Azimuth: $azimuth \&deg<br>"
           . "DX: $miles miles<br>";

    $station{graphs} =  '<a href="' . $c->config->{root_url}
           . "/signal_graph/$tuner_id/$tuner_number/$call"
           . '">Signal strength graphs</a><br>';

    # create Callsign icon if it doesn't exist yet
    my $png = $c->config->{image_dir} . "/$call.png";
    if (! -r $png) {
      if (! _icon_png($call,'white',$png)) {
        $c->response->body("FAIL: Can't create $call.png");
        $c->response->status(403);
        return 0;
      }
    }

    if ($color eq 'red')    { push @red_markers,    \%station }
    if ($color eq 'yellow') { push @yellow_markers, \%station }
    if ($color eq 'green')  { push @green_markers,  \%station }
    if ($color eq 'black')  { push @black_markers,  \%station }
  }

  $c->stash('tuner_id' => $tuner_id);
  $c->stash('tuner_number' => $tuner_number);
  $c->stash('tuner_longitude' => $tuner->longitude);
  $c->stash('tuner_latitude' => $tuner->latitude);
  $c->stash('red_markers' => \@red_markers);
  $c->stash('yellow_markers' => \@yellow_markers);
  $c->stash('green_markers' => \@green_markers);
  $c->stash('black_markers' => \@black_markers);
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

  my $entry = $c->model('DB::Signal')
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
  my ($self,$c,$tuner_id,$tuner_number,$callsign,$start_time,$end_time) = @_;

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
      '--lower-limit', '0', '--upper-limit', '100', '--rigid',
      '--start', $start_time,
      '--end', $end_time,
      '--vertical-label', 'Relative Quality',
      '--height', 300,
      '--width', 600,
      "DEF:call_raw_strength=$call_rrd_file:strength:MAX",
      "DEF:call_raw_sig_noise=$call_rrd_file:sig_noise:MAX",
      "DEF:ch_raw_strength=$channel_rrd_file:strength:MAX",
      "DEF:ch_raw_sig_noise=$channel_rrd_file:sig_noise:MAX",
      # change undefined call values to zero
      'CDEF:call_strength=call_raw_strength,UN,0,call_raw_strength,IF',
      'CDEF:call_sig_noise=call_raw_sig_noise,UN,0,call_raw_sig_noise,IF',
      # zero out ch_sig_noise and strength if there's call data or if it's NaN
      'CDEF:is_call_data=call_raw_sig_noise,UN,0,1,IF',
      'CDEF:ch_sig_noise_nan=ch_raw_sig_noise,UN',
      'CDEF:ch_strength_nan=ch_raw_strength,UN',
      'CDEF:ch_strength=is_call_data,ch_strength_nan,+,0,ch_raw_strength,IF',
      'CDEF:ch_sig_noise=is_call_data,ch_sig_noise_nan,+,0,ch_raw_sig_noise,IF',
      # plot the non-decodeable (RF channel) in red colors, decodeable in green
      'AREA:ch_strength#660000:Relative Strength (undecodeable signal)',
      'AREA:ch_sig_noise#FF0000:Relative Signal/Noise (undecodeable signal)',
      'AREA:call_sig_noise#00FF00:Relative Signal/Noise (decodeable signal)',
      'LINE:call_strength#006600:Relative Strength  (decodeable signal)'];
    $c->detach( $c->view('RRDGraph') );
    return;
  }
  else {
    # just a callsign or channel number, not both
    $c->stash->{'graph'} = [
      '--lower-limit', '0', '--upper-limit', '100', '--rigid',
      '--start', $start_time,
      '--end', $end_time,
      '--vertical-label', 'Relative Quality',
      '--height', 300,
      '--width', 600,
      "DEF:raw_strength=$call_rrd_file:strength:MAX",
      "DEF:raw_sig_noise=$call_rrd_file:sig_noise:MAX",
      # change undefined values to zero
      'CDEF:strength=raw_strength,UN,0,raw_strength,IF',
      'CDEF:sig_noise=raw_sig_noise,UN,0,raw_sig_noise,IF',
      'LINE:strength#00FF00:Relative Strength',
      'LINE:sig_noise#0000FF:Relative Signal/Noise' ];
    $c->detach( $c->view('RRDGraph') );
    return;
  }
}


=head2 tuner_location_data

Retrieve the latitude and longitude for a tuner

=cut

sub tuner_location_data :Global {
  my ($self, $c, $tuner_id) = @_;

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
  $c->stash('tuner_latitude'  => $tuner->latitude);
  $c->stash('tuner_longitude' => $tuner->longitude);
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


# if any tuner is unknown, send back an error message
sub _check_tuners {
  my ($self,$c,@check_tuner_info) = @_;

  while (@check_tuner_info) {
    my $tuner_id =     shift @check_tuner_info;
    my $tuner_number = shift @check_tuner_info; 

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



=head2 all_stations_data

Retreive all stations ever received by tuners

=cut

sub all_stations_data :Global {
  my ($self, $c, @tuner_info) = @_;

  my @black_markers;

  $self->_check_tuners($c,@tuner_info);

  my $tuner_id =     shift @tuner_info;
  my $tuner_number = shift @tuner_info; 

  my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});

  my $rs = $c->model('DB::Signal')->search({'tuner_id' => $tuner_id,
                                              'tuner_number' => $tuner_number});
  while(my $signal = $rs->next) {
    my $gc_tuner = Geo::Calc->new( lat => $tuner->latitude,
                                   lon => $tuner->longitude,
                                   units => 'mi');
    my $miles = $gc_tuner->distance_to({lat => $signal->callsign->latitude,
                                        lon => $signal->callsign->longitude},
                                       -1);
    my $azimuth = int($gc_tuner->bearing_to({lat => $signal->callsign->latitude,
                                           lon => $signal->callsign->longitude},
                                           -1));

    my %station;

    $station{tuner_id} = $tuner_id;
    $station{tuner_number} = $tuner_number;
    $station{distance} = $miles;
    $station{azimuth} = $azimuth;

    my $call = $signal->callsign->callsign;
    $station{callsign} = $call;  # can't use key of call, it trashes javascript
    $station{latitude} = $signal->callsign->latitude;
    $station{longitude} = $signal->callsign->longitude;
    $station{info} = 
           '<br>RF channel ' . $signal->callsign->rf_channel . '<br>'
         . 'Virtual channel ' . $signal->callsign->virtual_channel . '<br>'
         . $signal->callsign->city_state . '<br>'
         . 'ERP ' . $signal->callsign->erp_kw .'<br>'
         . 'RCAMSL ' . $signal->callsign->rcamsl . '<br>';
    $station{first_in} = 'first in '
      . DateTime::Format::HTTP->format_datetime(
          DateTime::Format::SQLite->parse_datetime($signal->first_rx_date))
      . '<br>';
    $station{last_in} = 'last in '
      . DateTime::Format::HTTP->format_datetime(
          DateTime::Format::SQLite->parse_datetime($signal->rx_date))
      . '<br>';
    $station{azimuth_dx} = "Azimuth: $azimuth \&deg<br>"
      . "DX: $miles miles<br>";

    $station{graphs} =  '<a href="' . $c->config->{signal_graph_url} 
      . "$tuner_id/$tuner_number/$call\">Signal strength graphs</a><br>";

    # create Callsign icon if it doesn't exist yet
    my $png = $c->config->{image_dir} . "/$call.png";
    if (! -r $png) {
      if (! _icon_png($call,'white',$png)) {
        $c->response->body("FAIL: Can't create $call.png");
        $c->response->status(403);
        return 0;
      }
    }
  push @black_markers,  \%station;
  }
  # sort @black_markers by distance,callsign,tuner_id,tuner_number
  $c->stash('tuner_id' => $tuner_id);
  $c->stash('tuner_number' => $tuner_number);
  $c->stash('tuner_longitude' => $tuner->longitude);
  $c->stash('tuner_latitude' => $tuner->latitude);
### sort goes here....
  $c->stash('black_markers' => \@black_markers);
  $c->detach( $c->view('JSON') );
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
