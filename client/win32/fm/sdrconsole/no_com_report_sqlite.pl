# Tune SDR console and read sqlite database for stations detected. Send report scan results to web site.
#
# Written July 25, 2022 by Russell Dwarshuis
use strict 'vars';
use feature 'say';
use English;
use Getopt::Std;
use Win32;
use LWP;
use DateTime;
use DateTime::Format::ISO8601;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use DBI;
use DBD::Sqlite;
use EV;

our ($opt_d,$opt_f,$opt_h,$opt_s,$opt_t,$opt_T,$opt_u);
getopts('dhp:P:s:t:T:u:');

my $sqlite_file = $opt_f ? $opt_f : "$ENV{APPDATA}\\SDR-RADIO.com (V3)\RDSDatabase.sqlite";
my $report_interval = $opt_T ? $opt_T : 5*60;
my $spot_url = $opt_u ? $opt_u : 'http://rabbitears.info/tvdx/fm_spot';
help() if $opt_t =~ /\D/;
help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;
help() if $report_interval < 300;

# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);

EV::timer(0, $report_interval, sub {
  my $scan = { signal => {}, tuner_key => 0+$opt_t };
  my $end_epoch = time;
  my $start_epoch = $end_epoch - $report_interval;
  
  my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite_file",
                         undef,undef,{sqlite_open_flags => SQLITE_OPEN_READONLY});
  
  my $sql = "select TimeUTC, Frequency, PICode, PICount from RDSStations where TimeUTC between $start_epoch and $end_epoch;";
  my $sth = $dbh->prepare($sql);
  $sth->execute or die "sqlite failure: ".$dbh->errstr();
  
  my ($time,$freq,$pi,$count);
  while (($time,$freq,$pi,$count) = $sth->fetchrow()) {
	  my $dt = DateTime::Format::ISO8601->format_datetime(DateTime->from_epoch(epoch => $time));
	  say "$dt $freq $pi $count" if $debug;
	  $scan->{signal}->{$freq} = {pi_code => $pi+0, time => $dt};
  }
  
  $sth->finish;
  $dbh->disconnect;
  
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
});

EV::run;


sub help {
 print <<"EOHELP";

Continuously scan the FM broadcast band using SDR Console on this computer
and send detected station identication to a website where the results
an be viewed on a map.

Program options
-d Print debugging information.
-f SDR Console log file.  Defaults to $sqlite_file
   use / instead of \\ in path names.
-h Print help (you're reading it)
-t Mandatory ID sumber so web site can know what tuner is where.  Contact
   the author for an ID number.
-T send scan results every (this many seconds).  Default $report_interval seconds.
   Minimum of 300 seconds.
-u URL to send data to (developer may ask you to set this to help debug).
EOHELP
  exit;
}

