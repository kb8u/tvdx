#!/usr/bin/perl

#use strict;
use feature 'say';
use Getopt::Std;
use Mojo::UserAgent;
use Mojo::DOM;
use DateTime;
use DateTime::Format::MySQL;
use List::Util 'all';

use lib './lib';
use tvdx::Model::DB;


our ($opt_d, $opt_h);
getopts('dh');
help() if $opt_h;
 
my $fm_fcc_rs = tvdx::Model::DB->new()->resultset('FmFcc');

my $sql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);

#my $site = 'https://picodes.nrscstandards.org/fs_pi_codes_allocated.html';
my $site = 'https://rabbitears.info/tvdx/root/static/pi.html';
#my $site = 'https://rabbitears.info/tvdx/root/static/p.html';
my $ua = Mojo::UserAgent->new;

my $res = $ua->get($site)->result;

if ($res->is_error)    {
  say $res->message if $opt_d;
  exit 1;
}

unless ($res->is_success)  {
  say "not successsful" if $opt_d;
  exit 1;
}
process_res($res);

  


sub process_res {
  my ($res) = @_;

  for my $row ($res->dom->find('tr')->each) {
    next if $row->at('th');
    my $td = $row->find('td')->to_array;
    my $callsign = $td->[0]->at('a')->text;
    my $pi_code = hex($td->[1]->at('code')->text);
    my $frequency = $td->[2]->text;
    my $city_state = $td->[4]->text . ', ' . $td->[5]->text;
    my $country = 'USA';
    my $lat_lon = $td->[6]->text;

    $frequency =~ s/\.//;
    $frequency .= '0000';

    $lat_lon =~ s/^\s+//;
    $lat_lon =~ s/\s+$//;
    my @lat_lon = split /[^0-9\.]+/,$lat_lon;
    my $lattude = $lat_lon[0] + $lat_lon[1]/60 + $lat_lon[2]/3600;
    my $longitude = -1*($lat_lon[3] + $lat_lon[4]/60 + $lat_lon[5]/3600);

    # create entry in fm_fcc?
    my ($fcc_row) = $fm_fcc_rs->find({'frequency' => $frequency,
                                      'callsign' => $callsign,
                                      'end_date' => undef});
    if (!defined $fcc_row || $fcc_row == 0) {
      unless (all {defined $_} ($pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country)) {
        say ("Missing or bad data in row: ",join ' ',$pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country) if $opt_d;
        next;
      }
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
        say ("Couldn't create new fm_fcc row with $pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country") if $opt_d;
        next;
      }
    }
    # else row exists, just update it if pi_code is different.
    elsif ($fcc_row->pi_code != $pi_code) {
      say "$callsign has incorrect pi on wtfda, was ",$fcc_row->pi_code," should be $pi_code" if $opt_d;
      $fcc_row->update({
        'pi_code' => $pi_code,
        'last_fcc_lookup' => $sql_now,
      });
    }
  }
}


sub help {
  print <<EOH;
Scrape nrsc for pi's to fix wtfda pi's in error and update fm_fcc database.

-d for debug information
EOH
  exit;
}
