#!/usr/bin/perl
# scan tuner on Silicon Dust HDHomeRun
# Sends resluts to web site.
#
# This version sends the raw scan.  Written 5/24/2013 by Russell Dwarshuis

use strict 'vars';
use LWP;
use XML::Simple;
use LWP::Simple;
use Data::Dumper;

my $ua = LWP::UserAgent->new;

my $SPOT_URL = 'http://127.0.0.1:3000/raw_spot';

# program used to interface with tuner
my $CONFIG_PROGRAM = '/usr/bin/hdhomerun_config';

# tuner ID; can use FFFFFFFF if it's the only one on network
my $TUNER_ID = '1038E55C';

# which tuner to scan
my $TUNER = '/tuner0/';

my $DEBUG = 1;

if (! -x $CONFIG_PROGRAM) {
  print "$CONFIG_PROGRAM not found or can't be run.\n";
  exit;
}

my $found_tuner_id = $TUNER_ID;

my $user_id = "TunerID_$found_tuner_id" . "_$TUNER";
$user_id =~ s/\///g; # get rid of slashes in /tunerX/ for XML names to be proper


SCAN: while(1) {
  my $scan = {}; # information reported to web site
  $scan->{user_id} = $user_id;

  my ($freq,$channel,$modulation,$strength,$sig_noise,$symbol_err,$tsid,$virtual);

  # scan tuner
  print "trying to run $CONFIG_PROGRAM $TUNER_ID scan $TUNER\n" if $DEBUG;
  open SCAN, "$CONFIG_PROGRAM $TUNER_ID scan $TUNER |" or die "can't run scan";
  while(<SCAN>) {
    print $_ if $DEBUG;
    if ($_ =~ /^SCANNING:\s+(\d+)\s+\(us-bcast:(\d+)/) {
      # add all information for previous channel unless this is the first
      if ($freq) {
        $scan->{rf_channel}->{$channel}->{modulation} = $modulation,
        $scan->{rf_channel}->{$channel}->{strength} = $strength,
        $scan->{rf_channel}->{$channel}->{sig_noise} = $sig_noise,
        $scan->{rf_channel}->{$channel}->{symbol_err} = $symbol_err,
        $scan->{rf_channel}->{$channel}->{tsid} = $tsid,
        $scan->{rf_channel}->{$channel}->{virtual} = $virtual;
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
    if ($_ =~ /^PROGRAM\s+(\d+):\s+(\S+)\s+(\S+)/) {
      $virtual->{$1}->{channel} = $2;
      $virtual->{$1}->{name} = $3;
    }
  }
  # get last channel in scan
  if ($freq) {
    $scan->{rf_channel}->{$channel}->{modulation} = $modulation,
    $scan->{rf_channel}->{$channel}->{strength} = $strength,
    $scan->{rf_channel}->{$channel}->{sig_noise} = $sig_noise,
    $scan->{rf_channel}->{$channel}->{symbol_err} = $symbol_err,
    $scan->{rf_channel}->{$channel}->{tsid} = $tsid,
    $scan->{rf_channel}->{$channel}->{virtual} = $virtual;
  }
  print "scan finished.\n" if $DEBUG;

  # Nothing more to do unless RF detected
  if (! $scan->{rf_channel}) {
    print "No channels found in scan!  Waiting 10 seconds before trying again...\n" if $DEBUG;
    sleep 10; # don't try to rapidly run hdhomerun_config over and over on a locked tuner
    next SCAN;
  }

  my $xml = XMLout($scan);;
print Dumper $scan;
print "\n\n\n";
print "$xml\n";
exit;

  print "Sending results to $SPOT_URL\n" if $DEBUG;
  my $req = HTTP::Request->new(POST => $SPOT_URL);
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("xml=$xml");
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

}
