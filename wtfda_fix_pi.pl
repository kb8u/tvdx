#!/usr/bin/perl

use strict;
use feature 'say';
use Getopt::Std;
use Mojo::UserAgent;
use Mojo::DOM;
use DateTime;
use DateTime::Format::MySQL;
use List::Util 'all';

use FindBin;
use lib "$FindBin::Bin/lib";
use tvdx::Model::DB;


# debug and help options
our ($opt_d, $opt_h);
getopts('dh');
help() if $opt_h;
 
my $fm_fcc_rs = tvdx::Model::DB->new()->resultset('FmFcc');

my $sql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);

open my $nrsc_errors, '>', "$FindBin::Bin/root/static/nrsc_errors.html";
print $nrsc_errors "<HTML><BODY>$sql_now checking nrsc<br>";

my $site = 'https://picodes.nrscstandards.org/fs_pi_codes_allocated.html';
my $ua = Mojo::UserAgent->new;

my $res = $ua->get($site)->result;

if ($res->is_error)    {
  print $nrsc_errors $res->message,'<br>';
  say $res->message if $opt_d;
  exit 1;
}

unless ($res->is_success)  {
  print $nrsc_errors "GET not successful<br>";
  say "not successsful" if $opt_d;
  exit 1;
}

for my $row ($res->dom->find('tr')->each) {
  next if $row->at('th');
  my $td = $row->find('td')->to_array;
  my $callsign = $td->[0]->at('a')->text;
  next if $callsign =~ /.*\-FM\d+$/; # don't add repeaters
  my $pi_code = hex($td->[1]->at('code')->text);
  my $frequency = $td->[2]->text;
  my $city_state = $td->[4]->text . ', ' . $td->[5]->text;
  my $country = 'USA';
  my $lat_lon = $td->[6]->text;

  $frequency =~ s/\.//;
  $frequency .= '0000';

  $lat_lon =~ s/^\s+//;
  $lat_lon =~ s/\s+$//;
  my @lat_lon = split /[^0-9\.NSEW]+/,$lat_lon;
  my $latitude = $lat_lon[0] + $lat_lon[1]/60 + $lat_lon[2]/3600;
  $latitude = $lat_lon[3] eq 'S' ? $latitude * -1 : $latitude;
  my $longitude = $lat_lon[4] + $lat_lon[5]/60 + $lat_lon[6]/3600;
  $longitude = $lat_lon[7] eq 'W' ? $longitude * -1 : $longitude;

  # create entry in fm_fcc?
  my ($fcc_row) = $fm_fcc_rs->find({'frequency' => $frequency,
                                    'callsign' => $callsign,
                                    'end_date' => undef});
  if (!defined $fcc_row || $fcc_row == 0) {
    unless (all {defined $_} ($pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country)) {
      my $err = join ' ', 'Missing or bad data in row:',$pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country;
      print $nrsc_errors $err, '<br>';
      say $err if $opt_d;
      next;
    }
    print $nrsc_errors "$callsign not in wtfda<br>";
    say "creating $callsign" if $opt_d;
    my $entry = $fm_fcc_rs->create({
      'callsign' => $callsign,
      'frequency' => $frequency,
      'city_state' => $city_state,
      'country' => $country,
      'latitude' => $latitude,
      'longitude' => $longitude,
      'pi_code' => $pi_code,
      'start_date' => $sql_now,
      'last_fcc_lookup' => $sql_now,
    });
    if (!$entry) {
      my $err = "Couldn't create new fm_fcc row with $pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country";
      print $nrsc_errors $err,'<br>';
      say $err if $opt_d;
      next;
    }
  }
  # else row exists, just update it if pi_code is 0
  elsif ($fcc_row->pi_code == 0) {
    my $err = "$callsign has no pi on wtfda, was ".$fcc_row->pi_code." should be $pi_code";
    print $nrsc_errors $err, '<br>';
    say $err if $opt_d;
    $fcc_row->update({
      'pi_code' => $pi_code,
      'last_fcc_lookup' => $sql_now,
    });
  }
}

print $nrsc_errors 'Finished processing nrsc<br></BODY></HTML>';
close $nrsc_errors;


sub help {
  print <<EOH;
Scrape nrsc for pi's to fix wtfda pi's in error and update fm_fcc database.

-d for debug information
EOH
  exit;
}
