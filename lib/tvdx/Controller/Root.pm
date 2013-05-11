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
use lib '/home/kb8u/tvdx/lib';
use dist;
use image_dir;
use labeled_icon;

BEGIN { extends 'Catalyst::Controller' }

my $RRD_DIR = '/home/kb8u/tvdx/rrd';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
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

    $c->response->body( "Under construction, come back soon!" );
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
    $rrd_file = "$RRD_DIR/$rrd_file.rrd";

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
  # WWPX repeater in DC (on same channel)
  if (   ($spot->{'callsign'} ne 'WWPX2')
      && ($spot->{'callsign'} !~ /^[CWKX](\d\d)*[A-Z]{2,3}$/)) {
    return 0;
  }

  return 0 if $spot->{'virtual_channel'} !~ /^\d+\.{0,1}\d*$/;

  return 1;
}


# Check or update (if > 1 week old) or create call sign in fcc table
# Returns 1 on success, 0 on failure.
sub _call_current {
  my ( $self,$c,$p_callsign,$channel,$virtual_channel ) = @_;

  my $week_ago = DateTime->from_epoch( 'epoch' => (time() - 604800) );

  my ($fcc_call) = $c->model('DB::Fcc')->find({'callsign' => $p_callsign});

  # query FCC site for call sign
  if ((! $fcc_call) || (DateTime::Format::SQLite->parse_datetime($fcc_call->last_fcc_lookup) < $week_ago)) {
    my @tvq = split /\n/, get("http://www.fcc.gov/fcc-bin/tvq?call=$p_callsign&list=4&size=9");
    # loop through matches, parse output and look for exact call match
    foreach (@tvq) {
      next if $_ !~ /^\|/; # line must begin with |
      # see http://www.fcc.gov/mb/audio/am_fm_tv_textlist_key.txt
      my ($blank,$call,$not_used1,$service,$fcc_channel,$antenna,$offset,$tv_zone,$not_used2,$tv_status,$city,$state,$country,$file_number,$erp,$not_used3,$haat,$not_used4,$facility_id,$n_or_s,$lat_deg,$lat_min,$lat_sec,$w_or_e,$lon_deg,$lon_min,$lon_sec,$greedy_corporate_overlord,$dx_km,$dx_miles,$azimuth,$rcamsl,$polarization,$ant_id,$ant_rot,$ant_struct_number,$archagl) = split /\s*\|/,$_;
      # only digital TV entries are relavent
      next if $service !~ /(DT|DC|DD|LD|DS|DX)/;
      # remove any suffix from end
      $call =~ s/\-.*//;
      # FCC channel match must be exact
      next if $fcc_channel != $channel;

      # FCC returns longer matches for short calls, match must be exact
      next if (uc $call ne uc $p_callsign);

      # remove white space from position data, erp, haat, facility id, state
      map { $_ =~ s/\s+//g; } ($n_or_s,$lat_deg,$lat_min,$lat_sec,$w_or_e,$lon_deg,$lon_min,$lon_sec,$erp,$haat,$facility_id,$state);
      # remove extra white space from rcamsl
      $rcamsl =~ s/\s+/ /;
      # clean up erp
      $erp =~ s/kW/ kW/;
      $erp =~ s/\. kW/.0 kW/;
      # remove white space at end of owner
      $greedy_corporate_overlord =~ s/\s+$//;
      # remove white space at end of city
      $city =~ s/\s+$//;

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
        $c->model('DB::Fcc')->update({'last_fcc_lookup' => $sqlite_now, });
        return 1;
      }
    }
    return 0; # couldn't find call in FCC site, or it didn't respond
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
    push @reception_locations, $tuner->owner_id . "<p><a href=\"http://www.rabbitears.info/tvdx/one_tuner_map/$tuner_id/$tuner_number\">map for just this location</a>";
  }

  $c->stash(tuner_info => \@tuner_info);
  $c->stash(reception_locations => \@reception_locations);
  $c->stash(template => 'Root/many_tuner_map.tt');
  $c->stash(current_view => 'HTML');

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

  $c->stash(tuner        => $tuner);
  $c->stash(tuner_number => $tuner_number);
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
    my ($miles,$azimuth) =
      dist($signal->callsign->latitude.','.$signal->callsign->longitude,
                      $tuner->latitude.','.           $tuner->longitude);

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

    $station{graphs} =  '<a href="http://www.rabbitears.info/tvdx/signal_graph/'
           . "$tuner_id/$tuner_number/$call\">Signal strength graphs</a><br>";

    # create Callsign icon if it doesn't exist yet
    if (! -r image_dir() . "/$call.png") {
      if (! icon_png($call,'white')) {
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
 
  $c->stash(tuner        => $tuner);
  $c->stash(tuner_number => $tuner_number);
  $c->stash(callsign     => $callsign);
  $c->stash(template     => 'Root/signal_graph.tt');
  $c->stash(current_view => 'HTML');
}


=head2 render_graph

Renders a graph of signal strength and signal/noise for the given tuner,
callsign and date range

=cut

sub render_graph :Global {
  my ($self,$c,$tuner_id,$tuner_number,$callsign,$start_time,$end_time) = @_;
  $c->stash->{'graph'} = [
    '--lower-limit', '0', '--upper-limit', '100', '--rigid',
    '--start', $start_time,
    '--end', $end_time,
    '--vertical-label', 'Relative Quality',
    '--height', 300,
    '--width', 600,
    "DEF:raw_strength=$RRD_DIR/$tuner_id"."_$tuner_number"."_$callsign.rrd:strength:MAX",
    "DEF:raw_sig_noise=$RRD_DIR/$tuner_id"."_$tuner_number"."_$callsign.rrd:sig_noise:MAX",
    # change undefined values to zero
    'CDEF:strength=raw_strength,UN,0,raw_strength,IF',
    'CDEF:sig_noise=raw_sig_noise,UN,0,raw_sig_noise,IF',
    'LINE:strength#00FF00:Relative Strength',
    'LINE:sig_noise#0000FF:Relative Signal/Noise' ];
  $c->detach( $c->view('RRDGraph') );
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
    if (none { $_ eq $tuner->owner_id } @reception_locations) {
      push @reception_locations, $tuner->owner_id;
    }
  }


  $c->stash(tuner_info => \@tuner_info);
  $c->stash(reception_locations => \@reception_locations);
  $c->stash(template => 'Root/all_signals_ever_map.tt');
  $c->stash(current_view => 'HTML');
}


# if any tuner is unknown, send back an error message
sub _check_tuners {
  my ($self,$c,@check_tuner_info) = @_;

  while (@check_tuner_info) {
    my $tuner_id =     shift @check_tuner_info;
    my $tuner_number = shift @check_tuner_info; 

    my $tuner = $c->model('DB::Tuner')->find({'tuner_id'=>$tuner_id});
    if (! $tuner) {
      $c->response->body("FAIL: Tuner $tuner_id is not registered with site");
      $c->response->status(403);
      $c->detach();
    }
    if ($tuner_number ne 'tuner0' && $tuner_number ne 'tuner1') {
      $c->response->body("FAIL: Tuner number must be tuner0 or tuner1");
      $c->response->status(403);
      $c->detach();
    }
  }
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
    my ($miles,$azimuth) =
      dist($signal->callsign->latitude.','.$signal->callsign->longitude,
                      $tuner->latitude.','.           $tuner->longitude);
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

    $station{graphs} =  '<a href="http://www.rabbitears.info/tvdx/signal_graph/'
      . "$tuner_id/$tuner_number/$call\">Signal strength graphs</a><br>";

    # create Callsign icon if it doesn't exist yet
    if (! -r image_dir() . "/$call.png") {
      if (! icon_png($call,'white')) {
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
