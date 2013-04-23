# sub dist and related subroutines are based on public domain script dist.pl
# See http://www.indo.com/distance/dist.pl
#
# Calculations assume a spherical Earth with radius 6367 km.  
#
# Here are some examples of acceptable location formats:
#
#   40:26:46N,79:56:55W
#   40:26:46.302N 79:56:55.903W
#   40°26'21"N 79d58'36"W
#   40d 26' 21" N 79d 58' 36" W
#   40.446195N 79.948862W
#   40.446195 -79.948862
#

sub dist {
    my ($loc_a,$loc_b) = @_;
    my($lat1,$long1) = &parse_location($loc_a);
    my($lat2,$long2) = &parse_location($loc_b);

    my $dist = &great_circle_distance($lat1,$long1,$lat2,$long2);
    $dist *= 0.000621371192; # convert to miles

    my $heading=radians_to_degrees(initial_heading($lat1,$long1,$lat2,$long2));

    # round to 3 significant digits since that's all we are justified
    # in printing given the spherical earth assumption.
    return(round_to_3($dist),(sprintf('%.0f',$heading)));
}

# given coordinates of two places in radians, compute distance in meters
sub great_circle_distance {
    my ($lat1,$long1,$lat2,$long2) = @_;

    # approx radius of Earth in meters.  True radius varies from
    # 6357km (polar) to 6378km (equatorial).
    my $earth_radius = 6367000;

    my $dlon = $long2 - $long1;
    my $dlat = $lat2 - $lat1;
    my $a = (sin($dlat / 2)) ** 2 
	    + cos($lat1) * cos($lat2) * (sin($dlon / 2)) ** 2;
    my $d = 2 * atan2(sqrt($a), sqrt(1 - $a));

    # This is a simpler formula, but it's subject to rounding errors
    # for small distances.  See http://www.census.gov/cgi-bin/geo/gisfaq?Q5.1
    # my $d = &acos(sin($lat1) * sin($lat2)
    #               + cos($lat1) * cos($lat2) * cos($long1-$long2));

    return $earth_radius * $d;
}

# compute the initial bearing (in radians) to get from lat1/long1 to lat2/long2
sub initial_heading {
    my ($lat1,$long1,$lat2,$long2) = @_;

    BEGIN {
	$::pi = 4 * atan2(1,1);
    }

    # note that this is the same $d calculation as above.  
    # duplicated for clarity.
    my $dlon = $long2 - $long1;
    my $dlat = $lat2 - $lat1;
    my $a = (sin($dlat / 2)) ** 2 
	    + cos($lat1) * cos($lat2) * (sin($dlon / 2)) ** 2;
    my $d = 2 * atan2(sqrt($a), sqrt(1 - $a));
    
    my $heading = acos((sin($lat2) - sin($lat1) * cos($d))
                   / (sin($d) * cos($lat1)));
    if (sin($long2 - $long1) < 0) {
	$heading = 2 * $::pi - $heading;
    }
    return $heading;
}

# return an angle in radians, between 0 and pi, whose cosine is x
sub acos {
    my($x) = @_;
    die "bad acos argument ($x)\n" if (abs($x) > 1.0);
    return atan2(sqrt(1 - $x * $x), $x);
}

# round to 3 significant digits
sub round_to_3 {
    my ($num) = @_;
    my ($lg,$round);
    if ($num == 0) {
	return 0;
    }
    $lg = int(log(abs($num)) / log(10.0));	# log base 10 of num
    $round = 10 ** ($lg - 2);
    return int($num / $round + 0.5) * $round;
}

# round to nearest integer
sub round_to_int {
    return int(abs($_[0]) + 0.5) * ($_[0] < 0 ? -1 : 1);
}

# print a location in a canonical form
sub loc_to_string {
    my($lat,$long) = @_;
    
    $lat  = &radians_to_degrees($lat);
    $long  = &radians_to_degrees($long);

    my $ns = "N";
    my $ew = "E";

    if ($lat < 0) {
	$lat = -$lat;
	$ns = "S";
    }
    if ($long < 0) {
	$long = -$long;
	$ew = "W";
    }
    $lat = int($lat * 3600 + 0.5);
    my $lat_string = sprintf("%d:%02d:%02d%s",
			     int($lat/3600), 
			     int(($lat - 3600*int($lat / 3600))/60),
			     $lat - 60*int($lat / 60),
			     $ns);
    $long = int($long * 3600 + 0.5);
    my $long_string = sprintf("%d:%02d:%02d%s",
			      int($long/3600), 
			      int(($long - 3600*int($long / 3600))/60),
			      $long - 60*int($long / 60),
			      $ew);

    return "$lat_string $long_string";
}

# convert a string which looks like "34:45:12N,15:34:10W" into a pair
# of degrees.  Also accepts "34.233N,90.134E" etc.
sub parse_location {
    my($str) = @_;
    my($lat,$long);
    
    if ($str =~ /^([0-9:.\260'"d -]*)([NS]*)[, ]+([0-9:.\260'"d -]*)([EW]*)$/i) {
	return undef if (!defined($lat = &parse_degrees($1)));
	$lat *= (($2 eq "N" || $2 eq "n") ? 1.0 : -1.0);
	return undef if (!defined($long = &parse_degrees($3)));
	$long *= (($4 eq "E" || $4 eq "e") ? 1.0 : -1.0);
	return(&degrees_to_radians($lat), &degrees_to_radians($long));
    } else {
	return undef;
    }
}

# given a bearing in degrees, return a string "north", "southwest", 
# "east-southeast", etc.
sub heading_string {
    my($deg) = @_;
    my($rounded,$s); 
    my(@dirs) = ("north","east","south","west"); 
    $rounded = &round_to_int($deg / 22.5) % 16; 
    if (($rounded % 4) == 0) { 
        $s = $dirs[$rounded/4]; 
    } else { 
        $s = $dirs[2 * int(((int($rounded / 4) + 1) % 4) / 2)]; 
        $s .= $dirs[1 + 2 * int($rounded / 8)]; 
        if ($rounded % 2 == 1) { 
	    $s = $dirs[&round_to_int($rounded/4) % 4] . "-" . $s;
        } 
    } 
    return $s; 
} 

BEGIN { $::pi = 4 * atan2(1,1); }
sub degrees_to_radians {
    return $_[0] * $::pi / 180.0;
}
sub radians_to_degrees {
    return $_[0] * 180.0 / $::pi;
}

# convert a string like 34:45:12.34 or 38:40 or 34.124 or 34d45'12.34"
# or 25° 02' 30" to degrees
# (also handles a leading `-')
sub parse_degrees {
    my($str) = @_;
    my($d,$m,$s,$sign);

    # yeah, this could probably be done with one regexp.
    if ($str =~ /^\s*(-?)([\d.]+)\s*(:|d|\260)\s*([\d.]+)\s*(:|\')\s*([\d.]+)\s*\"?\s*$/) {
	$sign = ($1 eq "-") ? -1.0 : 1.0;
	$d = $2 + 0.0;
	$m = $4 + 0.0;
	$s = $6 + 0.0;
    } elsif ($str =~ /^\s*(-?)([\d.]+)\s*(:|d|\260)\s*([\d.]+)(\')?\s*$/) {
	$sign = ($1 eq "-") ? -1.0 : 1.0;
	$d = $2 + 0.0;
	$m = $4 + 0.0;
	$s = 0.0;
    } elsif ($str =~ /^\s*(-?)([\d.]+)(d|\260)?\s*$/) {
	$sign = ($1 eq "-") ? -1.0 : 1.0;
	$d = $2 + 0.0;
	$m = 0.0;
	$s = 0.0;
    } else {
	die "parse_degrees: can't parse $str\n";
    }
    return ($sign * ($d + ($m / 60.0) + ($s / 3600.0)));
}

1;
