#!/usr/bin/perl

use strict;
use feature 'say';
use Getopt::Std;

use FindBin;
use lib "$FindBin::Bin/lib";
use tvdx;
use tvdx::Model::DB;

tvdx::Model::DB->config->{connect_info} = tvdx->config->{'Model::DB'}->{connect_info};

our ($opt_d, $opt_h);
getopts('dh');
help() if $opt_h;
 
my $sql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);

if (   -M "$FindBin::Bin/root/static/nrsc_errors.html" > .1
    || -M "$FindBin::Bin/root/static/wtfda_errors.html" > .1) {
  say "wtfda_to_db.pl and/or wtfda_fix_pi.pl have not run recently" if $opt_d;
  exit;
}

my $fm_fcc_rs = tvdx::Model::DB->new()->resultset('FmFcc')->search(
  {end_date => undef,
   last_fcc_lookup => { '<' => \"DATE_SUB(CURDATE(),INTERVAL 1 DAY)"}});
$fm_fcc_rs->update({end_date => \"NOW()"});


sub help {
  print <<EOH;
Set end_date in fm_fcc table when last_fcc_lookup is not recent

-d for debug information
EOH
  exit;
}
