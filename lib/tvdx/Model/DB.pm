package tvdx::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'tvdx::Schema',
    
    connect_info => {
#        dsn => 'dbi:SQLite:tvdx.db',
        dsn => 'dbi:SQLite:dbname=/home/rjd/tvdx/tvdx.db',
        user => '',
        password => '',
        on_connect_do => q{PRAGMA foreign_keys = ON},
    }
);

=head1 NAME

tvdx::Model::DB - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<tvdx>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<tvdx::Schema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.41

=head1 AUTHOR

Russell Dwarshuis

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
