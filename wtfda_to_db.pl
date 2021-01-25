#!/usr/bin/perl

use strict;
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

my $site = 'https://db.wtfda.org';
my $ua = Mojo::UserAgent->new;

my $res = $ua->get($site)->result;
my $csrftoken;

if ($res->is_error)    {
  say $res->message if $opt_d;
  exit 1;
}

if ($res->is_success)  {
  
  my $cookies = $ua->cookie_jar->all;
  for my $cookie (@{$cookies}) {
    $csrftoken = $cookie->value if $cookie->name eq 'csrftoken';
  }
}
else {
  say "not successsful" if $opt_d;
  exit 1;
}

say "csrftoken: $csrftoken" if $opt_d;
#BUG: Can't get numperpage to work, access is denied
#$res = $ua->post($site => form => {numperpage => 3000, csrfmiddlewaretoken => $csrftoken})->result;
#if ($res->is_error)    {
#  say "POST failed: ",$res->message if $opt_d;
#  exit 1;
#}

my $page_str = $res->dom->find('h3+div')->first->text;
my $last_page;
if ($page_str =~ /page:\s+\d+\s+of\s+(\d+)/i) {
  $last_page = $1;
  say "last page number $last_page" if $opt_d;
}
else {
  say "Can't find last page number" if $opt_d;
  exit;
}

process_res($res);
for (my $page=2; $page <= $last_page; $page++) {
  say "processing page $page" if $opt_d;
  my $url = "$site/fac_frequency/down/$page";
  process_res($ua->get($url)->result);
}
  


sub process_res {
  my ($res) = @_;

  for my $row ($res->dom->find('#content>table tr')->each) {
    my $td = $row->find('td')->to_array;
    my $callsign = $td->[0]->text;
    next unless $callsign;  # column descriptions row?
    my $relay_of = $td->[1]->text;
    my $frequency = $td->[2]->text;
    my $city = $td->[3]->text;
    my $s_p = $td->[4]->text;
    my $country = $td->[5]->text;
    my $mode = $td->[6]->text;
    my $lang = $td->[7]->text;
    my $format = $td->[8]->text;
    my $slogan = $td->[9]->text;
    my $erp_h = $td->[10]->text;
    my $erp_v = $td->[11]->text;
    my $haat_h = $td->[12]->text;
    my $haat_v = $td->[13]->text;
    my $lat = $td->[14]->text;
    my $lon = $td->[15]->text;
    my $pi_code = hex $td->[16]->text;
    my $ps_info = $td->[17]->text; 
    my $radiotext = $td->[18]->text;
    my $pty = $td->[19]->text;
    my $remarks = $td->[20]->text;

    $callsign =~ s/\s+//g;
    $frequency =~ s/\.//;
    $frequency .= '0000';
    my $city_state = "$city, $s_p";
    my @lat = split '-',$lat;
    my $latitude = $lat[0] + $lat[1]/60 + $lat[2]/3600;
    my @lon = split '-',$lon;
    my $longitude = -1 * ($lon[0] + $lon[1]/60 + $lon[2]/3600);
    
    # create entry in fm_fcc?
    my ($fcc_row) = $fm_fcc_rs->find({'frequency' => $frequency,
                                      'callsign' => $callsign,
                                      'end_date' => undef});
    if (!defined $fcc_row || $fcc_row == 0) {
      unless (all {defined $_} ($pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country)) {
        say ("Missing or bad data in row: ",$pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country) if $opt_d;
        next;
      }
      my $entry = $fm_fcc_rs->create({
        'callsign' => $callsign,
        'relay_of' => $relay_of,
        'frequency' => $frequency,
        'city_state' => $city_state,
        'country' => $country,
        'mode' => $mode,
        'lang' => $lang,
        'format' => $format,
        'slogan' => $slogan,
        'erp_h' => $erp_h,
        'erp_v' => $erp_v,
        'haat_h' => $haat_h,
        'haat_v' => $haat_v,
        'latitude' => $latitude,
        'longitude' => $longitude,
        'pi_code' => $pi_code,
        'ps_info' => $ps_info,
        'radiotext' => $radiotext,
        'pty' => $pty,
        'remarks' => $remarks,
        'start_date' => $sql_now,
        'last_fcc_lookup' => $sql_now,
      });
      if (!$entry) {
        say ("Couldn't create new fm_fcc row with $pi_code,$callsign,$latitude,$longitude,$sql_now,$city_state,$country") if $opt_d;
        next;
      }
    }
    # else row exists, just update it.
    else {
      $fcc_row->update({
        'callsign' => $callsign,
        'relay_of' => $relay_of,
        'frequency' => $frequency,
        'city_state' => $city_state,
        'country' => $country,
        'mode' => $mode,
        'lang' => $lang,
        'format' => $format,
        'slogan' => $slogan,
        'erp_h' => $erp_h,
        'erp_v' => $erp_v,
        'haat_h' => $haat_h,
        'haat_v' => $haat_v,
        'latitude' => $latitude,
        'longitude' => $longitude,
        'pi_code' => $pi_code,
        'ps_info' => $ps_info,
        'radiotext' => $radiotext,
        'pty' => $pty,
        'remarks' => $remarks,
        'last_fcc_lookup' => $sql_now,
      });
    }
  }
}


sub help {
  print <<EOH;
Scrape db.wtfda.org and insert into fm_fcc database.

-d for debug information
EOH
  exit;
}
