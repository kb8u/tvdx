use strict;
use warnings;
use Test::More;
use DateTime;

BEGIN { use_ok 'tvdx::Model::DB' }

my $schema;
ok($schema = tvdx::Model::DB->new(), 'schema created');

my $fcc_rs = $schema->resultset('FmFcc');
ok($fcc_rs, 'FmFcc resultset exists');

my $call = $fcc_rs->find({callsign => 'WEMU'})->callsign;
is($call, 'WEMU', "callsign test");

my $signalreport = $schema->resultset('FmSignalReport')->find(25);
ok($signalreport, 'signal_report key 25 exists');


my $start = DateTime->new(year => 2021, month => 1, day => 1, hour => 5, minute => 24);
my $end   = DateTime->new(year => 2021, month => 2, day => 2, hour => 5, minute => 25);
my $sig_date;
ok ($sig_date = $schema->resultset('FmSignalReport')->tuner_date_range(1,$start,$end),'signal_reports between two dates');
diag('count: ' . $sig_date->count);
ok($sig_date->count == 25, 'found 25 signals between the dates');
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

my $last_24;
ok($last_24 =$schema->resultset('FmSignalReport')->all_last_24, 'found all last 24');

ok($last_24->count > 0, 'more than 0 in last 24 hours');
ok($last_24->first->fcc_key->callsign =~ /[A-Z]+/, 'first of last_24 has a callsign');
ok($last_24->first->tuner_key->description eq '820T2 cheap dongle', 'and a tuner description');
diag('user name: '.$last_24->first->tuner_key->user_key->user);

done_testing(13);
