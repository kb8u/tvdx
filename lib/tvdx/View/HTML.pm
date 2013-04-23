package tvdx::View::HTML;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    INCLUDE_PATH => [ tvdx->path_to('root','src') ],
    render_die => 1,
);

=head1 NAME

tvdx::View::HTML - TT View for tvdx

=head1 DESCRIPTION

TT View for tvdx.

=head1 SEE ALSO

L<tvdx>

=head1 AUTHOR

Russell Dwarshuis,  KB8U

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
