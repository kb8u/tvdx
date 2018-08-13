use utf8;
package tvdx::Schema::Result::TunerDebug;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::TunerDebug

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<tuner_debug>

=cut

__PACKAGE__->table("tuner_debug");

=head1 ACCESSORS

=head2 tuner_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "tuner_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_id>

=back

=cut

__PACKAGE__->set_primary_key("tuner_id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2018-08-12 20:15:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rLXk2uCxYDpwHV7DMjneMQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
