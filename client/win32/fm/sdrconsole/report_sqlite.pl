# Tune SDR console and read sqlite database for stations detected. Send report scan results to web site.
#
# Written May 15, 2021 by Russell Dwarshuis
use strict 'vars';
use feature 'say';
use English;
use Getopt::Std;
use Win32;
use Win32::Serialport;
use LWP;
use DateTime;
use DateTime::Format::ISO8601;
use JSON;
use LWP::Simple;
use Compress::Bzip2 ':utilities';
use DBI;
use DBD::Sqlite;
use EV;

our ($opt_c,$opt_d,$opt_h,$opt_p,$opt_P,$opt_s,$opt_t,$opt_T,$opt_u);
getopts('c:dhp:P:s:t:T:u:');

my $file_path = $opt_p ? $opt_p : "$ENV{APPDATA}/SDR-RADIO.com (V3)";
my $file_name = $opt_P ? $opt_P : 'RDSDatabase.sqlite';
my $port = $opt_c ? $opt_c : 'COM4';
my $scan_interval = $opt_s ? $opt_s : 8;
my $report_interval = $opt_T ? $opt_T : 5*60;
my $spot_url = $opt_u ? $opt_u : 'http://rabbitears.info/tvdx/fm_spot';
help() if $opt_t =~ /\D/;
help() if $opt_h;
help() unless $opt_t;
my $debug = $opt_d;
help() if $report_interval < 300;

# prevent child processes from opening a console window
Win32::SetChildShowWindow(0);

my $sdr = new Win32::SerialPort($port) || die "can't open $port: $EXTENDED_OS_ERROR";
$sdr->baudrate(57600);
$sdr->parity('none');
$sdr->databits(8);
$sdr->stopbits(1);
$sdr->handshake('none');
$sdr->write_settings || die "Can't change port settings: $EXTENDED_OS_ERROR";

my $frequency = 107900000;

my $scan = { signal => {}, tuner_key => 0+$opt_t };

my $ev = EV::timer(0, $scan_interval, sub {
  # tune to the next frequency
  $frequency = $frequency == 107900000 ? 88100000 : $frequency + 200000;
  say "tuning to $frequency" if $debug;
  $sdr->write(sprintf('FA%011d;',$frequency));
  # TODO: check if frequency change was accepted
});

my $rv = EV::timer($report_interval, $report_interval, sub {
  my $scan = { signal => {}, tuner_key => 0+$opt_t };
  my $end_epoch = time;
  my $start_epoch = $end_epoch - $report_interval;
  
  my $dbh = DBI->connect("dbi:SQLite:dbname=$file_path/$file_name",
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
-c COM port that SDR Console is on.  You will will probably need to install a
   virtual serial port such as com0com (http://com0com.sourceforge.net/) and
   configure SDR Console to use it. Defaults to $port
-d Print debugging information.
-h Print help (you're reading it)
-p SDR Console database path.  Defaults to $file_path
   use / instead of \\ in path names.
-P SDR Console database file name.  Defaults to $file_name
-s Change frequency every this many seconds.  Default is $scan_interval seconds
-t Mandatory ID sumber so web site can know what tuner is where.  Contact
   the author for an ID number.
-T send scan results every (this many seconds).  Default $report_interval seconds.
   Minimum of 300 seconds.
-u URL to send data to (developer may ask you to set this to help debug).
EOHELP
  exit;
}

