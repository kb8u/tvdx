# read SDR# RDSDataLogger csv file and report scan results to web site.
#
# Written Feb 22, 2021 by Russell Dwarshuis
use strict 'vars';
use feature 'say';
use Getopt::Std;
use FindBin '$Bin';
use List::Util 'none';
use Data::Dumper;
use Win32;
use LWP;
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::ISO8601;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use File::Slurp;
use Try::Tiny;
use EV;

our ($opt_d,$opt_h,$opt_i,$opt_p,$opt_P,$opt_t,$opt_T,$opt_u);
getopts('dhi:p:P:t:T:u:');

help() if $opt_t =~ /\D/;
help() if $opt_h;
help() unless $opt_t;
my @ignore = split ',', $opt_i;
help() if ((scalar @ignore) % 2);
my $debug = $opt_d;
my $file_path = $opt_p ? $opt_p : 'C:/SDRSharp/RDSDataLogger';
my $file_prefix = $opt_P ? $opt_P : 'RDSDataLogger-';
my $interval = $opt_T ? $opt_T : 5*60;
help() if $interval < 300;
my $spot_url = $opt_u ? $opt_u : 'http://rabbitears.info/tvdx/fm_spot';


# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);


my $scan = { signal => {}, tuner_key => 0+$opt_t };
my $newest_reported_line;

my $ev = EV::timer(0, $interval, sub { 
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
  print Dumper \%ignore if $debug;

  my $fifteen_ago_dt =  DateTime->now(time_zone => DateTime::TimeZone->new(name=>'local'))->subtract(minutes => 15);
  say (scalar localtime, " Looking for log files") if $debug;
  my @line;
  # generate today's and yesterday's file names
  my $dt_tz = DateTime::TimeZone->new(name=>'local');
  my $dt_now = DateTime->now(time_zone => $dt_tz);
  my $tz_offset = DateTime::TimeZone->offset_as_string($dt_tz->offset_for_datetime($dt_now));
  $tz_offset =~ s/00$/:00/;
  my $today_file = "$file_path/$file_prefix" . $dt_now->ymd . '.csv';
  my $yesterday_file = "$file_path/$file_prefix" . $dt_now->subtract(days=>1)->ymd . '.csv';

  # slurp yesterday and today file into one
  try { @line = read_file($yesterday_file); }
  catch { say "couldn't open $yesterday_file: $_" if $debug; };
  try { push @line, (read_file($today_file)); }
  catch { say "couldn't open $today_file: $_" if $debug; };

  unless (@line) {
    say 'no stations in log file' if $debug;
    return;
  }
  if ($debug) { 
    say "lines read:";
    foreach (@line) { print }
  }

  for (my $i = $#line; $i >= 0; $i--) {
    if ($line[$i] eq $newest_reported_line) {
      if ($i == $#line) {
        say 'no new stations' if $debug;
	return;
      }
      say "saw last reported line, sending report" if $debug;
      report($scan);
      $scan = { signal => {}, tuner_key => 0+$opt_t };
      $newest_reported_line = $line[$#line];
      return;
    }
    my ($time,$frequency,$pi) = split ',', $line[$i]; 
    unless ($time && $frequency && $pi) {
      say "invalid line: $line[$i]" if $debug;
      next;
    }
    next if ($pi eq 'FFFF' || $pi eq '0000');
    # change to ISO8601 format
    $time =~ s/\//-/g; 
    $time =~ s/ /T/;
    $time .= ':00' . $tz_offset;
    my $line_dt = DateTime::Format::ISO8601->parse_datetime($time);
    say "line_dt: $line_dt fifteen_ago_dt: $fifteen_ago_dt" if $debug;;

    if ($line_dt < $fifteen_ago_dt) {
      # send scan
      report($scan);
      $scan = { signal => {}, tuner_key => 0+$opt_t };
      $newest_reported_line = $line[$#line];
      return;
    }
    else {
      if (none { hex $pi == $_ } @{$ignore{$frequency}}) {
        $scan->{signal}->{$frequency} = {pi_code => hex $pi, time => $time};
      }
      else { say "$frequency $pi is in ignore list" if $debug }
    }
  }

  # first time run if files have all been read
  $newest_reported_line = $line[$#line];
  report($scan);
});

EV::run;


sub report {
  my ($scan) = @_;

  unless (%{$scan->{signal}}) {
    say 'nothing to report' if $debug;
    return;
  }
  my $j = JSON->new->allow_nonref;
  my $json = $debug ? $j->pretty->encode($scan) : $j->encode($scan);
  print "JSON:\n$json" if $debug;
  my $bzipped = memBzip($json);

  say "Sending results to $spot_url" if $debug;
  my $req = HTTP::Request->new(POST => $spot_url);
  $req->content_type('application/octet-stream');
  $req->content_charset('binary');
  $req->content_length(length($bzipped));
  $req->content($bzipped);
  my $res = LWP::UserAgent->new->request($req);

  if ($debug) {
    say scalar localtime;
    say "Checking if web page got results ok";
    if ($res->is_success) {
      say $res->content;
    }
    else {
      say $res->status_line;
    }
  }
}


sub help {
 print <<'EOHELP';

Continuously scan the FM broadcast band on a software defined radio connected
to this computer and send detected station identication to a website where the
results can be viewed on a map.

Program options:
-d Print debugging information.
-h Print help (you're reading it)
-i Frequency/PI code combinations to ignore like 89.9,B205,103.7,83BC
   Also reads input from file ignore_pi.txt in installation directory,
   one entry per line, like 89.9,B205
-p RDS scan file path.  Defaults to C:/SDRSharp/RDSDataLogger
   use / instead of \ in path names.
-P RDS file prefix.  Defaults to RDSDataLogger-
-t Mandatory ID so web site can know what tuner is where.  Contact
     webmaster@rabbitears.info for an ID number.
-T send scan results every (this many minutes).  Default 5 minutes.  Minimum
   of 5 minutes.
-u URL to send data to (developer may ask you to set this to help debug).
EOHELP
  exit;
}

