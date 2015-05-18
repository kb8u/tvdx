#!/usr/bin/env perl
# scan tuner on Silicon Dust HDHomeRun
# Sends resluts to web site.
#
# This version sends a minimal amount of information to communicate the results
# of a scan.  Written 5/13/2015 by Russell Dwarshuis

use strict 'vars';
use Getopt::Std;
use LWP;
use JSON;
use LWP::Simple;
use Data::Compare;

my $ua = LWP::UserAgent->new;

my $SPOT_URL = 'http://www.rabbitears.info/tvdx/s';

# program used to interface with tuner
my $CONFIG_PROGRAM = '/usr/bin/hdhomerun_config';

# tuner ID; can use FFFFFFFF if it's the only one on network
my $TUNER_ID = 'FFFFFFFF';

# which tuner to scan
my $TUNER = '/tuner0/';

our ($opt_h,$opt_o,$opt_p,$opt_t,$opt_u,$opt_x,$opt_d);
getopts('ho:p:t:u:x:d');
help() if ($opt_h);
my $DEBUG = $opt_d;

my %override;
my @overrides = split /,/,$opt_o;
while(@overrides) { $override{pop @overrides} = pop @overrides; }
foreach my $ch (keys %override) {
  unless ($ch =~ /\d+/ && $ch >1 && $ch < 70) {
    print "Bad channel number in -o option.\n";
        help();
  }
  unless ($override{$ch} =~ /^\S+/) {
    print "Bad callsign in -o option.\n";
        help();
  }
}

$CONFIG_PROGRAM = $opt_p if ($opt_p);
if (! -x $CONFIG_PROGRAM) {
  print "$CONFIG_PROGRAM not found or can't be run.\n";
  help();
}

$TUNER = $opt_t if $opt_t;
unless ($TUNER eq '/tuner0/' || $TUNER eq '/tuner1/' || $TUNER eq '/tuner2/') {
  print "Invalid tuner ID.  Must be /tuner0/ or /tuner1/ or /tuner2/\n";
  exit 1;
}

$SPOT_URL = $opt_u if $opt_u;

my $found_tuner_id;
if ($opt_x) {
  $TUNER_ID = $opt_x;
  $found_tuner_id = $opt_x;
  if ($found_tuner_id !~ /^[0-9A-F]{8}$/) {
    print "Invalid tuner ID.  Must be 8 characters of 0-9 and A-F\n";
        exit 1;
  }
}
else {
  open DISCOVER, "\"$CONFIG_PROGRAM\" discover |" or die "Can't run $CONFIG_PROGRAM discover";
  while(<DISCOVER>) {
    if ($_ =~ /device\s+([0-9A-Fa-f]{8})\s+found/i) {
      $found_tuner_id = uc $1;
      print "Found hdhomerun device $found_tuner_id\n" if $DEBUG;
    }
  }
}
print "Reporting on scans of hdhomerun device $found_tuner_id tuner $TUNER\n" if $DEBUG;

my $int_tuner_id = hex($found_tuner_id);
$TUNER =~ /(\d)/;
my $int_tuner_number = $1;

my %last_scan;

SCAN: while(1) {
  my $scan = {}; # information reported to web site

  my ($freq,$channel,$modulation,$strength,$sig_noise,$symbol_err,$tsid,$virtual);

  # scan tuner
  print "trying to run $CONFIG_PROGRAM $TUNER_ID scan $TUNER\n" if $DEBUG;
  open SCAN, "$CONFIG_PROGRAM $TUNER_ID scan $TUNER |" or die "can't run scan";
  while(<SCAN>) {
    print $_ if $DEBUG;
    if ($_ =~ /^SCANNING:\s+(\d+)\s+\(us-bcast:(\d+)/) {
      # add all information for previous channel unless this is the first
      if ($freq) {
        $scan->{$channel}->{modulation} = $modulation,
        $scan->{$channel}->{strength} = $strength,
        $scan->{$channel}->{sig_noise} = $sig_noise,
        $scan->{$channel}->{symbol_err} = $symbol_err,
        $scan->{$channel}->{tsid} = $tsid,
        $scan->{$channel}->{virtual} = $virtual;
        if (exists $override{$channel}) {
          $scan->{$channel}->{reporter_callsign}
            = $override{$channel};
        }
      }
      $freq = $1;
      $channel = $2;
      $modulation = '';
      $strength = '';
      $sig_noise = '';
      $symbol_err = '';
      $tsid = '';
      $virtual = {};
    }
    if ($_ =~ /^LOCK:\s+(\S+)\s+\(ss=(\d+)\s+snq=(\d+)\s+seq=(\d+)\)/) {
      $modulation = $1;
      $strength   = $2;
      $sig_noise  = $3;
      $symbol_err = $4;
    }
    if ($_ =~ /^TSID: (0x[0-9A-Fa-f]{4})$/) {
      $tsid = hex($1);
    }
    if ($_ =~ /^PROGRAM\s+(\d+):\s+(\S+)\s(.+)/) {
      $virtual->{$1}->{channel} = $2;
      $virtual->{$1}->{name} = $3;
    }
  }
  # get last channel in scan
  if ($freq) {
    $scan->{$channel}->{modulation} = $modulation,
    $scan->{$channel}->{strength} = $strength,
    $scan->{$channel}->{sig_noise} = $sig_noise,
    $scan->{$channel}->{symbol_err} = $symbol_err,
    $scan->{$channel}->{tsid} = $tsid,
    $scan->{$channel}->{virtual} = $virtual;
    if (exists $override{$channel}) {
      $scan->{$channel}->{reporter_callsign}
        = $override{$channel};
    }
  }
  print "scan finished.\n" if $DEBUG;

  # Nothing more to do unless RF detected
  if (! $scan) {
    print "No channels found in scan!  Waiting 10 seconds before trying again...\n" if $DEBUG;
    sleep 10; # don't try to rapidly run hdhomerun_config over and over on a locked tuner
    undef %last_scan;
    next SCAN;
  }

  # set change flag on each channel if tsid or reporter_callsign or
  # any virtual channel changes
  for my $channel (keys %scan) {
    if (   $scan->{$channel}->{tsid} != 
           $last_scan->{$channel}->{tsid}
        || Compare($scan->{$channel}->{virtual},
                   $last_scan->{$channel}->{virtual})
          ) {
      $scan->{$channel}->{changed} = 1;
    }
  }

  # binary structure to send to web server.  Format is:
  # channels 2-36, 38-51 in order
  # 1 bit decodeable/not-decodeable + 7 bits signal strength
  # 1 bit change/no change from last scan + 7 bits quality
  # optional null terminated string of opt_o entered by user
  # JSON formatted scan information only for virtual channels that have changed
  my $blob;

  my $packed_dsignal;
  my $packed_cquality;
  my %virtual_changed;

  # only send spots for FCC licensed channels
  for my $channel (2..36,38..51) {
    $packed_dsignal .= pack('C', $scan->{channel}->{strength}
                                 + $scan->{channel}->{modulation} ? 128 : 0);
    $packed_cquality .= pack('C', $scan->{$channel}->{sig_noise}
                                 + $scan->{$channel}->{changed} ? 128 : 0);
  }

  print "Sending results to $SPOT_URL\n" if $DEBUG;
  my $req = HTTP::Request->new(POST => $SPOT_URL);
  $req->content_type('application/octet-stream');
  $req->content($blob);
  my $res = $ua->request($req);

  if ($DEBUG) {
    print "Checking if web page got results ok\n";
    if ($res->is_success) {
      print $res->content;
      print "\n";
    }
    else {
      print $res->status_line, "\n";
    }
  }

  # delete changed key on each channel before copy to %last_scan
  # so next scan won't have bogus changed key
  for my $channel (keys %scan) {
    delete $scan->{$channel}->{changed};
  }
  %last_scan = %scan;

}


sub help {
  print <<EOHELP;

Scan channels on a SiliconDust HDHomeRun tuner and logs results.
The tuner must already be configured for over-the-air reception.
Only looks for North America calls like WWJ,CKLW,WXYZ,XAAA, etc.

Scan results will soon be available at http://www.rabbitears.info/all_tuners
after you contact kb8u_vhf\@hotmail.com to let him know your location.

This program sends all scan results there, so your anti-virus program
may give you warnings about network activity.  It's normal, don't worry.

Program options:
-h print help (you're reading it)
-o over-ride a callsign onto a channel e.g. -o 32,WDUD,44,CRUD forces channel
   32 to use a callsign WDUD and 44 to use CRUD
-p Path to hdhomerun_config.exe (used to scan the tuner).  It is normally
   already installed from the CD that came with your tuner.
   Defaults to $CONFIG_PROGRAM
-t Which tuner to use (applicable only to dual-tuner models).
   Defaults to $TUNER
-u URL to send scan results to.  Only change this if you're working with
   the author.  Defaults to $SPOT_URL
-x Tuner ID.  Only needed if you have more than one HDHomeRun on your network.
   Defaults to FFFFFFFF
-d Prints debugging information while the script runs.  Try this if you're
   having problems.  Send the output to kb8u_vhf\@hotmail.com if you can't
   figure out what's wrong.
EOHELP
  exit;
}
