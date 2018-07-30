use strict;
use warnings;
use Test::More;
use DateTime;

BEGIN { use_ok 'tvdx::Model::DB' }

my $schema;
ok($schema = tvdx::Model::DB->new(), 'schema created');

my $fcc_rs = $schema->resultset('Fcc');
ok($fcc_rs, 'Fcc resultset exists');

my $call = $fcc_rs->find('WJBK')->callsign;
is($call, 'WJBK', "callsign test");

my $signalreport = $schema->resultset('SignalReport')->find(45128);
ok($signalreport, 'signal_report key 45128 exists');

ok($signalreport->color eq 'green', 'signal_report key 45128 color is green');

my $start = DateTime->new(year => 2018, month => 7, day => 22, hour => 5, minute => 24);
my $end   = DateTime->new(year => 2018, month => 7, day => 22, hour => 5, minute => 25);
my $sig_date;
ok ($sig_date = $schema->resultset('SignalReport')->tuner_date_range('1047FCDA','tuner1',$start,$end),'signal_reports between two dates');

ok($sig_date->count == 48, 'found 48 signals between the dates');

my $most_recent;
ok($most_recent = $schema->resultset('SignalReport')->most_recent, 'found most recent');
my $first_call = $most_recent->first->callsign->callsign;
ok($first_call, "found a callsign: $first_call in most_recent");

done_testing(10);
