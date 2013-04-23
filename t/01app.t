#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use XML::Simple;

BEGIN { use_ok 'Catalyst::Test', 'tvdx' }

my %h;

$h{'user_id'} = 'TunerID_DEADBEEF_tuner0';
$h{'tv_signal'} = [ { callsign => 'WXYZ', 'virtual_channel' => '7.1', 'sig_noise' => 42, 'strength' => 90, 'rf_channel' => 41, } ]; 
my $xml = XMLout(\%h);

ok(request("/automated_spot?xml=$xml")->is_success,'insert propagation report');

ok( request('/')->is_success, 'Request should succeed' );


done_testing();
