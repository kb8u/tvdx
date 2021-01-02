#!/usr/bin/perl

use strict 'vars';
use feature 'say';
use Getopt::Std;
use Capture::Tiny ':all';
use LWP;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use List::Util qw(sum all);
use List::MoreUtils 'uniq';
use Data::Dumper;

my $ua = LWP::UserAgent->new;
#my $spot_url = 'http://www.rabbitears.info/tvdx/fm_spot';
my $spot_url = 'http://www.rabbitears.info:3000/fm_spot';
my $cmd = '/home/pi/fmdx/client/rds_for.sh';

our ($opt_d,$opt_h,$opt_s,$opt_t);
getopts('dst:h');

help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;

do {
  my $scan = {'tuner_key' => $opt_t};
  for (my $freq = 87.9; $freq <= 107.9; $freq += .2) {
#  for (my $freq = 91.5; $freq <= 91.8; $freq += .2) {

    my $freq_str = sprintf('%.1f', $freq);

    if ($opt_s) {
      my $lbound = sprintf('%.1fM', $freq - .1);
      my $ubound = sprintf('%.1fM', $freq + .1);
      my ($stdout, $stderr, $exit) = capture {
        system(qq!/usr/bin/rtl_power -1 -i 6 -g 40.2 -f $lbound:$ubound:.1K!);
      };
      my @powers = split ', ', $stdout;
      @powers = splice @powers,6;
      my $power = scalar @powers ? sum(@powers)/@powers : undef;
      say "$freq_str $power" if $debug;
      $scan->{signal}->{$freq_str}->{s} = $power;

      # let the tuner finish clean-up, otherwise it may not tune properly
      sleep 2;
    }

    print "scanning $freq_str ... " if $debug;
    my ($stdout, $stderr, $exit) = capture {
      system( $cmd, $freq_str );
    };
    $stdout =~ s/"//g;
    my @line = split /\n/, $stdout;
    if (scalar @line > 3 && (all {$_ eq $line[0]} (@line))) {
      my $pi = hex $line[0];
      say "decoded pi $pi $line[0]" if $debug;
      $scan->{signal}->{$freq_str}->{pi} = hex $line[0] if $pi;
    }
    elsif ($debug) { say "no pi decoded." }
    
    # let the tuner finish clean-up, otherwise it may not tune properly
    sleep 2;
  }

  if (!exists $scan->{signal}) {
    say "No signals detected" if $debug;
    next;
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

#} while 1;
} while !$debug;

sub help {
 print <<'EOHELP';

Continuously scan the FM broadcast band on a software defined radio connected
to this computer and send detected station identication to a website where the
results can be viewed on a map.

Program options:
-h Print help (you're reading it)
-s Report signal strengths (experimental)
-t Mandatory ID so web site can know what tuner is where.  Contact
     kb8u_vhf@hotmail.com for an ID number.
-d Run only one band scan and print debugging information.
EOHELP
  exit;
}
