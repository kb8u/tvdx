use strict;
use warnings;
use Test::More;
use DateTime;

BEGIN { use_ok 'tvdx::Model::DB' }

my $schema;
ok($schema = tvdx::Model::DB->new(), 'schema created');

my $tuner_rs = $schema->resultset('FmTuner');
ok($tuner_rs, 'FmTuner resultset exists');

my $tuner = $tuner_rs->find({tuner_key =>1},{prefetch => 'user_key'});

ok($tuner->description eq '820T2 cheap dongle', "");
ok($tuner->user_key->email eq 'rjd@umich.edu', 'user email');
ok($tuner->user_key->description eq 'Cheap 820T2 dongle');

done_testing(6);
