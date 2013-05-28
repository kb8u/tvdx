package tvdx;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
    StackTrace
/;

extends 'Catalyst';

our $VERSION = '6.66';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in tvdx.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'tvdx',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    'View::JSON' => {
      expose_stash => [ qw(tuner_id tuner_number tuner_latitude tuner_longitude
                           reception_locations black_markers red_markers
                           yellow_markers green_markers) ] }

);

# Start the application
__PACKAGE__->setup();


=head1 NAME

tvdx - Catalyst based application

=head1 SYNOPSIS

    script/tvdx_server.pl

=head1 DESCRIPTION

Accept digital TV reception repors and display results on customizeable maps.

=head1 SEE ALSO

L<tvdx::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Russell Dwarshuis, KB8U

=head1 LICENSE

Copyright 2011 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
