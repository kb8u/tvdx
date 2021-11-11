#!/usr/bin/perl

use strict 'vars';
use feature 'say';
use Time::HiRes 'usleep';
use Getopt::Std;
use FindBin '$Bin';
use List::Util 'none';
use LWP;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::ISO8601;
use File::Slurp;
use Try::Tiny;
use GQRX::Remote;

my $ua = LWP::UserAgent->new;
my $spot_url = 'http://rabbitears.info/tvdx/fm_spot';
#my $spot_url = 'http://www.rabbitears.info:3000/fm_spot';

our ($opt_d,$opt_h,$opt_i,$opt_s,$opt_t);
getopts('dst:hi:');

help() if $opt_h;
help() unless $opt_t;

my $debug = $opt_d;

my %ignore; # like $ignore{899000000} = [45573] for 89.9,B205
if ($opt_i) {
  my @ignore = split ',', $opt_i;
  for (my $i = 0;$i <= $#ignore; $i+=2) {
    $ignore[$i] = $ignore[$i] * 1e6;
    $ignore[$i+1] = hex $ignore[$i+1];
    $ignore{$ignore[$i]} = [] unless exists $ignore{$ignore[$i]};
    push @{$ignore{$ignore[$i]}}, $ignore[$i+1];
  }
}
my $ignore_file = "$Bin/ignore_pi.txt";
my @ignore_file;
try { @ignore_file = read_file($ignore_file); }
catch { say "couldn't open $ignore_file: $_" if $debug; };
chomp @ignore_file;
@ignore_file = grep(/^\d{2,3}\.\d,[0-9a-f]{4}$/i,@ignore_file);
foreach (@ignore_file) {
  my ($freq,$pi) = split ',',$_;
  $freq *= 1e6;
  $ignore{$freq} = [] unless exists $ignore{$freq};
  push @{$ignore{$freq}}, hex $pi;
}

my $remote = GQRX::Remote->new();
remote_error() unless $remote->connect;
remote_error() unless $remote->set_demodulator_mode('WFM');
remote_error() unless $remote->set_squelch_threshold(-150);
remote_error() unless $remote->set_dsp_status(1);

do {
  my $scan = {'tuner_key' => $opt_t};
  for (my $freq = 881e5; $freq <= 1079e5; $freq += 2e5) {
    print "scanning $freq ... " if $debug;
    remote_error() unless $remote->set_frequency($freq);
    # clear RDS decoder out by turning it off and on again
    usleep(3e5);
    remote_error() unless $remote->set_rds_status(0);
    usleep(3e5);
    remote_error() unless $remote->set_rds_status(1);
    sleep(10);
    my $pi = $remote->get_rds_pi;
    remote_error() unless $pi;

    my $strength = $remote->get_signal_strength();
    remote_error() unless $strength;

    my $iso_now = DateTime::Format::ISO8601->parse_datetime(
         DateTime->now(time_zone => DateTime::TimeZone->new(name=>'UTC'))).'Z';

    say "$iso_now strength $strength pi $pi" if $debug;
    if (none { hex $pi == $_ } @{$ignore{$freq}}) {
      $scan->{signal}->{$freq}->{time} = $iso_now;
      $scan->{signal}->{$freq}->{s} = $strength;
      $scan->{signal}->{$freq}->{pi_code} = hex $pi;
    }
    else {say "$freq $pi is in ignore list" if $debug }

    # channel scan takes about 9 seconds, send reports every 5 minutes or so
    if (scalar %{$scan->{signal}} >=26) {
      spot($scan);
      $scan = {'tuner_key' => $opt_t};
    }
  }
} while (1);


sub spot {
  my ($scan) = @_;

  if (!exists $scan->{signal}) {
    say "No signals detected." if $debug;
  }
  else {
    my $j = JSON->new->allow_nonref;
    my $json = $debug ? $j->pretty->encode($scan) : $j->encode($scan);
    print "JSON:\n$json" if $debug;
    my $bzipped = memBzip($json);

    print "Sending results to $spot_url\n" if $debug;
    my $req = HTTP::Request->new(POST => $spot_url);
    $req->content_type('application/octet-stream');
    $req->content_charset('binary');
    $req->content_length(length($bzipped));
    $req->content($bzipped);
    my $res = $ua->request($req);

    if ($debug) {
      print "Checking if web page got results ok\n";
      if ($res->is_success) {
        print $res->content;
        print "\n";
      }
      else {
        print $res->status_line, "\n";
      }
    }
  }
}


sub remote_error {
  say "Error sending remote commands to gqrx.  Is it running?";
  say "Failed with error: " . $remote->error();
  exit;
};


sub help {
 print <<'EOHELP';

Continuously scan the FM broadcast band on a software defined radio connected
to this computer and send detected station identication to a website where the
results can be viewed on a map.

Program options:
-h Print help (you're reading it)
-i Frequency/PI code combinations to ignore like 89.9,B205,103.7,83BC
   Also reads input from file ignore_pi.txt in installation directory,
   one entry per line, like 89.9,B205
-t Mandatory ID so web site can know what tuner is where.  Contact
     kb8u_vhf@hotmail.com for an ID number.
-d Run only one band scan and print debugging information.
EOHELP
  exit;
}
