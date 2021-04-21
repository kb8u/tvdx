#!/usr/bin/perl

use strict 'vars';
use feature 'say';
use Getopt::Std;
use LWP;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use List::Util qw(sum all);
use List::MoreUtils 'uniq';
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::ISO8601;
use Data::Dumper;
use GQRX::Remote;

my $ua = LWP::UserAgent->new;
my $spot_url = 'http://rabbitears.info/tvdx/fm_spot';
#my $spot_url = 'http://www.rabbitears.info:3000/fm_spot';

our ($opt_d,$opt_h,$opt_s,$opt_t);
getopts('dst:h');

help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;

my $remote = GQRX::Remote->new();
remote_error() unless $remote->connect;
remote_error() unless $remote->set_demodulator_mode('WFM');
remote_error() unless $remote->set_dsp_status(1);

do {
  my $scan = {'tuner_key' => $opt_t};
  for (my $freq = 88100000; $freq <= 107900000; $freq += 200000) {
    print "scanning $freq ... " if $debug;
    remote_error() unless $remote->set_frequency($freq);
    # clear RDS decoder out.
    sleep(1);
    remote_error() unless $remote->set_rds_status(0);
    sleep(1);
    remote_error() unless $remote->set_rds_status(1);
    sleep(10);
    my $pi = $remote->get_rds_pi;
    remote_error() unless $pi;

    my $strength = $remote->get_signal_strength();
    remote_error() unless $strength;

    my $iso_now = DateTime::Format::ISO8601->parse_datetime(
         DateTime->now(time_zone => DateTime::TimeZone->new(name=>'UTC'))).'Z';

    say "$iso_now strength $strength pi $pi" if $debug;
    $scan->{signal}->{$freq}->{time} = $iso_now;
    $scan->{signal}->{$freq}->{s} = $strength;
    $scan->{signal}->{$freq}->{pi_code} = hex $pi;

    if (scalar %{$scan->{signal}} >=11) {
      spot($scan);
      $scan = {'tuner_key' => $opt_t};
    }
  }
  spot($scan);
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
-t Mandatory ID so web site can know what tuner is where.  Contact
     kb8u_vhf@hotmail.com for an ID number.
-d Run only one band scan and print debugging information.
EOHELP
  exit;
}
