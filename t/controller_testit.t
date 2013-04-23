use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'tvdx' }
BEGIN { use_ok 'tvdx::Controller::testit' }

ok( request('/testit')->is_success, 'Request should succeed' );
done_testing();
