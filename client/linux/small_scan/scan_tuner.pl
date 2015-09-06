#!/usr/bin/env perl
# scan tuner on Silicon Dust HDHomeRun
# Sends resluts to web site.
#
# This version sends a minimal amount of information to communicate the results
# of a scan.  Written 5/13/2015 by Russell Dwarshuis

use strict 'vars';
use feature 'say';
use Getopt::Long;
use Storable 'dclone';
use LWP;
use JSON;
use LWP::Simple;
use Data::Compare;
use Data::HexDump;

my $ua = LWP::UserAgent->new;

my ($scan_from_file,$print_help,$overrides);
# program used to interface with tuner
my $CONFIG_PROGRAM = '/usr/bin/hdhomerun_config';
# which tuner to scan
my $TUNER = '/tuner0/';
# where to send scans
my $SPOT_URL = 'http://www.rabbitears.info/tvdx/s';
# tuner ID; can use FFFFFFFF if it's the only one on network
my $TUNER_ID = 'FFFFFFFF';
my $DEBUG;

GetOptions("file=s" => \$scan_from_file,
           "help" => \$print_help,
           "overrides:s" => \$overrides,
           "hdhomerun_config:s" => \$CONFIG_PROGRAM,
           "tuner:s" => \$TUNER,
           "url:s" => \$SPOT_URL,
           "tuner_id:s" => \$TUNER_ID,
           "debug" => \$DEBUG );
help() if ($print_help);

my @scan_from_file = split ',', $scan_from_file;

my %override;
my @overrides = split /,/,$overrides;
while(@overrides) { $override{pop @overrides} = pop @overrides; }
foreach my $ch (keys %override) {
  unless ($ch =~ /\d+/ && $ch >1 && $ch < 70) {
    say "Bad channel number in -o option.";
        help();
  }
  unless ($override{$ch} =~ /^\S+/) {
    say "Bad callsign in -o option.";
        help();
  }
}

if (! -x $CONFIG_PROGRAM) {
  say "$CONFIG_PROGRAM not found or can't be run.";
  help();
}

unless ($TUNER eq '/tuner0/' || $TUNER eq '/tuner1/' || $TUNER eq '/tuner2/') {
  say "Invalid tuner ID.  Must be /tuner0/ or /tuner1/ or /tuner2/";
  exit 1;
}

my $found_tuner_id = 0;
unless ($scan_from_file) {
  if ($TUNER_ID ne 'FFFFFFFF') {
    $found_tuner_id = $TUNER_ID;
    if ($found_tuner_id !~ /^[0-9A-F]{8}$/) {
      say "Invalid tuner ID.  Must be 8 characters of 0-9 and A-F";
          exit 1;
    }
  }
  else {
    open DISCOVER, "\"$CONFIG_PROGRAM\" discover |" or die "Can't run $CONFIG_PROGRAM discover";
    while(<DISCOVER>) {
      if ($_ =~ /device\s+([0-9A-Fa-f]{8})\s+found/i) {
        $found_tuner_id = uc $1;
        say "Found hdhomerun device $found_tuner_id" if $DEBUG;
      }
    }
  }
  say "Reporting on scans of hdhomerun device $found_tuner_id tuner $TUNER" if $DEBUG;
}

my $int_tuner_id = hex($found_tuner_id);
$TUNER =~ /(\d)/;
my $int_tuner_number = $1;

my $last_scan;

SCAN: while(1) {
  my $scan = {}; # information reported to web site

  my ($freq,$channel,$modulation,$strength,$sig_noise,$symbol_err,$tsid,$virtual);

  # scan tuner
  say "trying to run $CONFIG_PROGRAM $TUNER_ID scan $TUNER" if ($DEBUG && ! $scan_from_file);
  if (! $scan_from_file) {
    open SCAN, "$CONFIG_PROGRAM $TUNER_ID scan $TUNER |" or die "can't run scan";
  }
  else {
    my $file = shift @scan_from_file;
    open(SCAN, "<", $file) or die "Can't open $scan_from_file"
  }
  
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
      $modulation = 0;
      $strength = '';
      $sig_noise = '';
      $symbol_err = '';
      $tsid = '';
      $virtual = {};
    }
    if ($_ =~ /^LOCK:\s+(\S+)\s+\(ss=(\d+)\s+snq=(\d+)\s+seq=(\d+)\)/) {
      # $modulation is used as high bit of $packed_dsignal
      $modulation = $1 eq '8vsb' ? 128 : 0;
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
  say "scan finished." if $DEBUG;

  # Nothing more to do unless RF detected
  if (! $scan) {
    say "No channels found in scan!  Waiting 10 seconds before trying again..." if $DEBUG;
    sleep 10; # don't try to rapidly run hdhomerun_config over and over on a locked tuner
    undef $last_scan;
    next SCAN;
  }

  # set change flag on each channel if tsid or reporter_callsign or
  # any virtual channel changes. 0 or 128 because it becomes high bit of $packed_cquality
  for my $channel (2..36,38..51) {
    $scan->{$channel}->{changed} = 0;

    if ( $scan->{$channel}->{tsid} != $last_scan->{$channel}->{tsid}) {
      say "channel $channel tsid changed since last scan" if $DEBUG;
      $scan->{$channel}->{changed} = 128;
    }
    if (! Compare($scan->{$channel}->{virtual},
                  $last_scan->{$channel}->{virtual})) {
      say "channel $channel virtual(s) changed since last scan" if $DEBUG;
      $scan->{$channel}->{changed} = 128;
    }
  }

  # binary structure to send to web server.  Format is:
  # channels 2-36, 38-51 in order
  # 1 bit decodeable/not-decodeable + 7 bits signal strength
  # 1 bit change/no change from last scan + 7 bits quality
  # optional null terminated string of --overrides entered by user
  # JSON formatted scan information only for virtual channels that have changed
  my $blob;

  my $packed_dsignal;
  my $packed_cquality;
  my $packed_changed_tsids;
  my $virtual_changed = {};

  # only send spots for FCC licensed channels
  for my $channel (2..36,38..51) {
    $packed_dsignal .= pack('C', $scan->{$channel}->{strength} + $scan->{$channel}->{modulation});
    $packed_cquality .= pack('C', $scan->{$channel}->{sig_noise} + $scan->{$channel}->{changed});
    if ($scan->{$channel}->{changed}) {
      $packed_changed_tsids .= pack('S', hex($scan->{channel}->{tsid}));
      $virtual_changed->{$channel} = $scan->{$channel}->{virtual};
    }
  }

  $blob = pack('NC',$int_tuner_id, $int_tuner_number);
  $blob .= $packed_dsignal . $packed_cquality;
  $blob .= pack('Z*', $overrides);
  $blob .= encode_json($virtual_changed);

  if ($DEBUG) {
    say "packed_dsignal:";
    print HexDump $packed_dsignal;
    say "packed_cquality:";
    print HexDump $packed_cquality;
    say "blob:";
    print HexDump $blob;
  }

  # only send at five minute interval unless debug is on
  while ( ! $DEBUG && time % 300) { sleep 1 }

  say "Sending results to $SPOT_URL" if $DEBUG;
  my $req = HTTP::Request->new(POST => $SPOT_URL);
  $req->content_type('application/octet-stream');
  $req->content($blob);
  my $res = $ua->request($req);

  if ($DEBUG) {
    say "Checking if web page got results ok";
    if ($res->is_success) {
      say $res->content;
      say "";
    }
    else {
      say $res->status_line, "";
    }
  }

  # delete changed key on each channel before copy to $last_scan
  # so next scan won't have bogus changed key
  for my $channel (2..36,38..51) {
    delete $scan->{$channel}->{changed};
  }
  $last_scan = dclone($scan);

  last unless scalar @scan_from_file;
}


sub help {
  say <<EOHELP;

Scan channels on a SiliconDust HDHomeRun tuner and logs results.
The tuner must already be configured for over-the-air reception.
Only looks for North America calls like WWJ,CKLW,WXYZ,XAAA, etc.

Scan results will soon be available at http://www.rabbitears.info/all_tuners
after you contact kb8u_vhf\@hotmail.com to let him know your location.

This program sends all scan results there, so your anti-virus program
may give you warnings about network activity.  It's normal, don't worry.

Program options:
--help prints this message.
--overrides over-rides callsigns onto a channel e.g. -o 32,WDUD,44,CRUD
   forces channel 32 to use a callsign WDUD and 44 to use CRUD
--hdhomerun_config Path to hdhomerun_config (used to scan the tuner).
   It is normally already installed from the CD that came with your tuner.
   Defaults to $CONFIG_PROGRAM
--tuner Which tuner to use (applicable only to dual-tuner models).
   Defaults to $TUNER
--tuner_id Tuner ID.  Only needed if you have more than one HDHomeRun on
   your network.  Defaults to FFFFFFFF
--debug Prints debugging information while the script runs.  Try this if
   you're having problems.  Send the output to kb8u_vhf\@hotmail.com if
   you can't figure out what's wrong.
EOHELP
  exit;
}
