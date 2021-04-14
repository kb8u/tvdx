#!/usr/bin/perl

use strict;
use feature 'say';
use Getopt::Std;
use Try::Tiny;
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
my $ua = Mojo::UserAgent->new->inactivity_timeout(90);

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


my $header = { 'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0',
               'Referer' => 'https://db.wtfda.org',
               'Upgrade-Insecure-Requests' => 1 };
my $form = { csrfmiddlewaretoken => $csrftoken,
             callsign => '',
             frequency => '', city => '', state => '', fac_country => '',
             prl => '', format => '', slogan => '', language => '',
             picode => '', numperpage => 3000 };
$res = $ua->post($site => $header => form => $form)->result;

my $last_page = 0;
if ($res) {
  my $page_str = $res->dom->find('h3+div')->first->text;
  if ($page_str =~ /page:\s+\d+\s+of\s+(\d+)/i) {
    $last_page = $1;
    say "last page number $last_page" if $opt_d;
    say "processing page 1" if $opt_d;
    process_res($res);
  }
  else {
    say "Can't find last page number" if $opt_d;
    exit;
  }
}
else {
  say "no result from first post" if $opt_d;
  exit 1;
}

PAGE: for (my $page=2; $page <= $last_page ; $page++) {
  say "processing page $page" if $opt_d;
  RETRY: for (my $retry = 0; $retry < 5; $retry++) {
    $res = 0;
    my $url = "$site/fac_frequency/down/$page";
    try {
      $res = $ua->get($url)->result;
    } catch {
      sleep 3*$retry;
      say "retrying $url" if $opt_d;
      next RETRY;
    };
    if ($res) {
      process_res($res);
    }
    next PAGE;
  }
  exit 1;
}
  

sub process_res {
  my ($res) = @_;

  for my $row ($res->dom->find('#content>table tr')->each) {
    my %row;
    my $td = $row->find('td')->to_array;
    $row{callsign} = $td->[0]->text;
    next unless $row{callsign};  # column descriptions row?
    $row{relay_of} = $td->[1]->text;
    $row{frequency} = $td->[2]->text;
    my $city = $td->[3]->text;
    my $s_p = $td->[4]->text;
    $row{country} = $td->[5]->text;
    $row{mode} = $td->[6]->text;
    $row{lang} = $td->[7]->text;
    $row{format} = $td->[8]->text;
    $row{slogan} = $td->[9]->text;
    $row{erp_h} = $td->[10]->text;
    $row{erp_v} = $td->[11]->text;
    $row{haat_h} = $td->[12]->text;
    $row{haat_v} = $td->[13]->text;
    my $lat = $td->[14]->text;
    my $lon = $td->[15]->text;
    $row{pi_code} = $td->[16]->text;
    $row{ps_info} = $td->[17]->text; 
    $row{radiotext} = $td->[18]->text;
    $row{pty} = $td->[19]->text;
    $row{remarks} = $td->[20]->text;

    $row{callsign} =~ s/\s+//g;
    $row{frequency} =~ s/\.//;
    $row{frequency} .= '00000';
    $row{city_state} = "$city, $s_p";
    my @lat = split '-',$lat;
    $row{latitude} = $lat[0] + $lat[1]/60 + $lat[2]/3600;
    my @lon = split '-',$lon;
    $row{longitude} = -1 * ($lon[0] + $lon[1]/60 + $lon[2]/3600);
    $row{pi_code} = ($row{pi_code }=~ /([0-9a-f]{1,4})/i) ? hex $1 : 0;

    $row{erp_h} = ($row{erp_h} =~ /^[+-]?\d+(\.\d+)?$/) ? $row{erp_h} : 0;
    $row{erp_v} = ($row{erp_v} =~ /^[+-]?\d+(\.\d+)?$/) ? $row{erp_v} : 0;
    $row{haat_h} = ($row{haat_h} =~ /^[+-]?\d+(\.\d+)?$/) ? $row{haat_h} : 0;
    $row{haat_v} = ($row{haat_v} =~ /^[+-]?\d+(\.\d+)?$/) ? $row{haat_v} : 0;

    if (   $row{frequency} < 87500000 || $row{frequency} > 108100000
        || $row{erp_h} < 0 || $row{erp_h} > 1000
        || $row{erp_v} < 0 || $row{erp_v} > 1000 
        || $row{haat_h} < -1000 || $row{haat_h} > 2000
        || $row{haat_v} < -1000 || $row{haat_v} > 2000
        || $row{latitude} < -90 || $row{latitude} > 90
        || $row{longitude} < -180 || $row{longitude} > 180
        || $row{pi_code} < 0 || $row{pi_code} > 65535
        || (length($row{callsign}) < 3) || (length($row{callsign}) > 10)
    ) {
      say "bad data read for $row{callsign}" if $opt_d;
      next;
    }

    $row{last_fcc_lookup} = $sql_now;
    
    # create entry in fm_fcc?
    my ($fcc_row) = $fm_fcc_rs->find({'frequency' => $row{frequency},
                                      'callsign' => $row{callsign},
                                      'end_date' => undef});
    if (!defined $fcc_row || $fcc_row == 0) {
      unless (all {defined $_} (@row{qw(pi_code callsign latitude longitude last_fcc_lookup city_state country)})) {
        say ("Missing or bad data in row: ",join ' ',@row{qw(pi_code callsign latitude longitude sql_now city_state country)}) if $opt_d;
        next;
      }
      say "creating row for $row{callsign}" if $opt_d;
      $row{start_date} = $sql_now;
      my $entry = $fm_fcc_rs->create(\%row);
      if (!$entry) {
        say ("Couldn't create new fm_fcc row with: ",join ' ',@row{qw(pi_code callsign latitude longitude last_fcc_lookup start_date city_state country)}) if $opt_d;
        next;
      }
    }
    # else row exists, just update it.
    else {
      say "updating database for $row{callsign}" if $opt_d;
      $fcc_row->update(\%row);
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
