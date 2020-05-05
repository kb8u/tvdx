# scan tuner on Silicon Dust HDHomeRun
# Sends results to web site.
#
# This version sends the raw scan.  Written 5/24/2013 by Russell Dwarshuis
# Added -o option Feb. 1, 2014 -rd
# Added bzip2 March 15, 2020 -rd

use strict 'vars';
use Getopt::Std;
use Win32;
use LWP;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';

my $ua = LWP::UserAgent->new;

# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);

my $SPOT_URL = 'http://www.rabbitears.info/tvdx/raw_spot';

# program used to interface with tuner
my $CONFIG_PROGRAM = 'C:\Progra~1\Silicondust\HDHomeRun\hdhomerun_config.exe';

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
  print "hdhomerun_config.exe can be installed from https://download.silicondust.com/hdhomerun/hdhomerun_windows.exe\n";
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
        if (exists $override{$channel}) {
          $scan->{rf_channel}->{$channel}->{reporter_callsign}
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
    $scan->{rf_channel}->{$channel}->{modulation} = $modulation,
    $scan->{rf_channel}->{$channel}->{strength} = $strength,
    $scan->{rf_channel}->{$channel}->{sig_noise} = $sig_noise,
    $scan->{rf_channel}->{$channel}->{symbol_err} = $symbol_err,
    $scan->{rf_channel}->{$channel}->{tsid} = $tsid,
    $scan->{rf_channel}->{$channel}->{virtual} = $virtual;
    if (exists $override{$channel}) {
      $scan->{rf_channel}->{$channel}->{reporter_callsign}
        = $override{$channel};
    }
  }
  print "scan finished.\n" if $DEBUG;

  # Nothing more to do unless RF detected
  if (! $scan->{rf_channel}) {
    print "No channels found in scan!  Waiting 10 seconds before trying again...\n" if $DEBUG;
    sleep 10; # don't try to rapidly run hdhomerun_config over and over on a locked tuner
    next SCAN;
  }

  my $j = JSON->new->allow_nonref;
  my $json = $DEBUG ? $j->pretty->encode($scan) : $j->encode($scan);
  my $bzipped = memBzip($json);

  if (length($json) < 500) {
    print "Scan not successful, length of JSON data is too short\n" if $DEBUG;
    sleep 1;
  }
  else {
    print "Sending results to $SPOT_URL\n" if $DEBUG;
    print "JSON:\n$json" if $DEBUG;
    my $req = HTTP::Request->new(POST => $SPOT_URL);
    $req->content_type('application/octet-stream');
    $req->content_charset('binary');
    $req->content_length(length($bzipped));
    $req->content($bzipped);
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
