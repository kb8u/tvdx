use strict;
use warnings;
use Test::More;
use DateTime;
use Scalar::Util 'looks_like_number';

BEGIN { use_ok 'tvdx::Model::DB' }

my $schema;
ok($schema = tvdx::Model::DB->new(), 'schema created');

my $fcc_rs = $schema->resultset('FmFcc');
ok($fcc_rs, 'FmFcc resultset exists');

my $call = $fcc_rs->find({callsign => 'WEMU'})->callsign;
is($call, 'WEMU', "callsign test");

my $signalreport = $schema->resultset('FmSignalReport')->find(25);
ok($signalreport, 'signal_report key 25 exists');

my $now = DateTime->now;
my $mysql_now = DateTime::Format::MySQL->format_datetime($now);

my $signal_insert = $schema->resultset('FmSignalReport')->create({
  'rx_date' => $mysql_now,
  'first_rx_date' => $mysql_now,
  'frequency' => 89100000,
  'tuner_key' => 1,
  'fcc_key' => 21760
});
ok($signal_insert,"created signal report of WEMU at $now");



my $start = DateTime->new(year => 2021, month => 1, day => 1, hour => 5, minute => 24);
my $end   = DateTime->new(year => 2021, month => 2, day => 2, hour => 5, minute => 25);
my $sig_date;
ok ($sig_date = $schema->resultset('FmSignalReport')->tuner_date_range(1,$start,$end),'signal_reports between two dates');
diag('count: ' . $sig_date->count);
ok($sig_date->count > 20, 'found more than 20 signals between the dates');
while(my $row = $sig_date->next) {
  my $fcc = $row->fcc_key;
  my $call = $fcc ? $row->fcc_key->callsign : 'none';
  diag("call: $call frequency: " . $row->frequency . ' date ' . $row->rx_date);
}

my $most_recent;
#ok($most_recent = $schema->resultset('SignalReport')->most_recent, 'found most recent');
ok($most_recent = $sig_date->most_recent, 'found most recent');
my $first_call = $most_recent->first->fcc_key->callsign;
ok($first_call, "found a callsign: $first_call in most_recent");
my $tuner_descr = $most_recent->first->tuner_key->description;
diag("tuner description: $tuner_descr");
my $user_descr =$most_recent->first->tuner_key->user_key->description;
diag("user description: $user_descr");

my $last_24;
ok($last_24 =$schema->resultset('FmSignalReport')->all_last_24, 'found all last 24');

ok($last_24->count > 0, 'more than 0 in last 24 hours');
ok($last_24->first->fcc_key->callsign =~ /[A-Z]+/, 'first of last_24 has a callsign');
ok($last_24->first->tuner_key->description eq 'LPDA at 15 feet', 'and a tuner description');
ok(looks_like_number($last_24->first->tuner_key->latitude), 'tuner latitude is a number');
ok($last_24->first->tuner_key->latitude == 42.293, 'latitude is 42.293');
ok(looks_like_number($last_24->first->fcc_key->latitude), 'fcc latitude is a number');
ok(looks_like_number($last_24->first->fcc_key->erp_h), 'erp_h is a number');
ok(looks_like_number($last_24->first->fcc_key->haat_h), 'haat_h is a number');
ok(looks_like_number($last_24->first->frequency), 'frequency is a number');

done_testing(20);
