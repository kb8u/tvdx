use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'tvdx' }
BEGIN { use_ok 'tvdx::Controller::Site' }

ok( request('/site')->is_success, 'Request should succeed' );
done_testing();
