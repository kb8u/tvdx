# read SDR# RDSDataLogger csv file and report scan results to web site.
#
# Written Feb 22, 2021 by Russell Dwarshuis
use strict 'vars';
use feature 'say';
use Getopt::Std;
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

our ($opt_d,$opt_h,$opt_p,$opt_P,$opt_t,$opt_T,$opt_u);
getopts('dhp:P:t:T:u:');

help() if $opt_t =~ /\D/;
help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;
my $file_path = $opt_p ? $opt_p : 'C:/SDRSharp/RDSDataLogger';
my $file_prefix = $opt_P ? $opt_P : 'RDSDataLogger-';
my $interval = $opt_T ? $opt_T : 5*60;
help() if $interval < 300;
my $spot_url = $opt_u ? $opt_u : 'http://rabbitears.info/tvdx/fm_spot';


# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);


# default so first loop will work correctly.
my $last_report_dt =  DateTime->now(time_zone => DateTime::TimeZone->new(name=>'local'))->subtract(seconds => $interval);
my $last_report_freq = 0;
my $latest_line_dt = undef;
my $latest_line_freq = 0;

my $scan = { signal => {}, tuner_key => 0+$opt_t };

my $ev = EV::timer(0, $interval, sub { 
  say (scalar localtime, " Looking for log files") if $debug;
  my @line;
  # generate today's and yesterday's file names
  my $dt_tz = DateTime::TimeZone->new(name=>'local');
  my $dt_now = DateTime->now(time_zone => $dt_tz);
  my $tz_offset = DateTime::TimeZone->offset_as_string($dt_tz->offset_for_datetime($dt_now));
  $tz_offset =~ s/00$/:00/;
  my $today_file = "$file_path/$file_prefix" . $dt_now->ymd . '.csv';
  my $yesterday_file = $file_prefix . $dt_now->subtract(days=>1)->ymd . '.csv';

  # slurp yesterday and today file into one
  try { @line = read_file($yesterday_file); }
  catch { say "couldn't open $yesterday_file: $_" if $debug; };
  try { push @line, (read_file($today_file)); }
  catch { say "couldn't open $today_file: $_" if $debug; };

  return unless @line;

  for (my $i = $#line; $i >= 0; $i--) {
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
    $latest_line_dt = $line_dt unless $latest_line_dt;
    $latest_line_freq = $frequency unless $latest_line_freq;

    if ($line_dt < $last_report_dt || ($line_dt == $last_report_dt && $frequency <= $last_report_freq)) {
      # send scan
      report($scan);
      $last_report_dt = $latest_line_dt;
      $last_report_freq = $latest_line_freq;
      $latest_line_dt = undef;
      $latest_line_freq = 0;
      $scan = { signal => {}, tuner_key => 0+$opt_t };
      return;
    }
    else {
      $scan->{signal}->{$frequency} = {pi_code => hex $pi, time => $time};
    }
  }

  # first time run if files have all been read
  report($scan) if (%{$scan->{signal}});
});

EV::run;


sub report {
  my ($scan) = @_;
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
  my $res = LWP::UserAgent->new->request($req);

  if ($debug) {
    print scalar localtime, "\n";
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


sub help {
 print <<'EOHELP';

Continuously scan the FM broadcast band on a software defined radio connected
to this computer and send detected station identication to a website where the
results can be viewed on a map.

Program options:
-d Print debugging information.
-h Print help (you're reading it)
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

