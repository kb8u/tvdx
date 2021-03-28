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
ok($tuner->description eq 'LPDA at 15 feet', "");
ok($tuner->user_key->email eq 'rjd@umich.edu', 'user email');
ok($tuner->user_key->description eq 'KB8U Ann Arbor, MI');

diag('last tuner_key is '.$tuner_rs->get_column('tuner_key')->max());

done_testing(6);
