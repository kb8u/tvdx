# read SDR# RDSDataLogger csv file and report scan results to web site.
#
# Written Feb 22, 2021 by Russell Dwarshuis
use strict 'vars';
use feature 'say';
use Getopt::Std;
use Win32;
use LWP;
use DateTime;
use DateTime::Format::ISO8601;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use File::Slurp;
use Try::Tiny;
use DateTime::TimeZone;
use EV;

our ($opt_d,$opt_h,$opt_p,$opt_T,$opt_t);
getopts('dp:T:t:h');

help() if $opt_T =~ /\D/;
my $report_minutes = $opt_T;

help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;
my $file_prefix = $opt_p ? $opt_p : 'C:/SDRSharp/RDSDataLogger/RDSDataLogger-';
my $interval = $opt_T ? $opt_T : 5*60;

my $ua = LWP::UserAgent->new;

# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);

my $spot_url = 'http://www.rabbitears.info:3000/fm_spot';
#my $spot_url = 'http://www.rabbitears.info/tvdx/fm_spot';


# defaults so first loop will work correctly.
my $last_report_dt =  DateTime->now(time_zone => DateTime::TimeZone->new(name=>'local'));
my $last_report_freq;

my $scan = { signal => {}, tuner_key => $opt_t };

my $ev = EV::timer($interval, $interval, sub { 
  my @line;
  # generate today's and yesterday's file names
  my $dt_tz = DateTime::TimeZone->new(name=>'local');
  my $dt_now = DateTime->now(time_zone => $dt_tz);
  my $tz_offset = DateTime::TimeZone->offset_as_string($dt_tz->offset_for_datetime($dt_now));
  my $today_file = $file_prefix . $dt_now->ymd . '.csv';
  my $yesterday_file = $file_prefix . $dt_now->subtract(days=>1)->ymd . '.csv';

  # slurp yesterday and today file into one
  try { @line = read_file($yesterday_file); }
  catch { say "couldn't open $yesterday_file: $_" if $debug; };
  try { push @line, (read_file($today_file)); }
  catch { say "couldn't open $today_file: $_" if $debug; };

  for (my $i = $#line; $i != 0; $i--) {
    my ($time,$frequency,$pi) = split ',', $line[$i]; 
    next if $pi eq 'FFFF';
    $time =~ s/\//-/g; # change to ISO8601 format
    $time =~ s/ /T/;
    $time .= ':00' . $tz_offset;
    my $line_dt = DateTime::Format::ISO8601->parse_datetime($time);

    if (   (!defined $last_report_freq || $frequency == $last_report_freq)
        && ($line_dt <= $last_report_dt)) {
      # send scan
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
      $last_report_freq = $frequency;
      $last_report_dt = $line_dt;
      $scan = { signal => {}, tuner_key => $opt_t };
      return;
    }
    else {
      $scan->{signal}->{$frequency}->{pi_code} = hex $pi;
    }
  }
});

EV::run;


sub help {
 print <<'EOHELP';

Continuously scan the FM broadcast band on a software defined radio connected
to this computer and send detected station identication to a website where the
results can be viewed on a map.

Program options:
-h Print help (you're reading it)
-p RDS scan file prefix.  Defaults to C:/SDRSharp/RDSDataLogger/RDSDataLogger-
-T send scan results every (this many minutes).  Default 5 minutes.  Minimum
   of 5 minutes.
-t Mandatory ID so web site can know what tuner is where.  Contact
     kb8u_vhf@hotmail.com for an ID number.
-d Run only one band scan and print debugging information.
EOHELP
  exit;
}

