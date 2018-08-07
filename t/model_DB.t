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

my $signalreport = $schema->resultset('SignalReport')->find(8823);
ok($signalreport, 'signal_report key 8823 exists');

ok($signalreport->color eq 'red', 'signal_report key 8823 color is red');

my $start = DateTime->new(year => 2018, month => 7, day => 22, hour => 5, minute => 24);
my $end   = DateTime->new(year => 2018, month => 7, day => 22, hour => 5, minute => 25);
my $sig_date;
ok ($sig_date = $schema->resultset('SignalReport')->tuner_date_range('1047FCDA','tuner1',$start,$end),'signal_reports between two dates');

diag('count: ' . $sig_date->count);
ok($sig_date->count == 56, 'found 56 signals between the dates');

my $most_recent;
#ok($most_recent = $schema->resultset('SignalReport')->most_recent, 'found most recent');
ok($most_recent = $sig_date->most_recent, 'found most recent');
while(my $row = $most_recent->next) {
  my $fcc = $row->callsign;
  my $call = $fcc ? $row->callsign->callsign : 'none';
  diag("call: $call channel: " . $row->rf_channel);
}
my $first_call = $most_recent->first->callsign->callsign;
ok($first_call, "found a callsign: $first_call in most_recent");

done_testing(10);
