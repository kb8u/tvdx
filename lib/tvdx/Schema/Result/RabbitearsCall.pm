use utf8;
package tvdx::Schema::Result::RabbitearsCall;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::RabbitearsCall

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

=head1 TABLE: C<rabbitears_call>

=cut

__PACKAGE__->table("rabbitears_call");

=head1 ACCESSORS

=head2 re_call_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 callsign

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 re_rval

  data_type: 'varchar'
  is_nullable: 1
  size: 10000

=head2 last_re_lookup

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "re_call_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "callsign",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "re_rval",
  { data_type => "varchar", is_nullable => 1, size => 10000 },
  "last_re_lookup",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</re_call_key>

=back

=cut

__PACKAGE__->set_primary_key("re_call_key");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2018-07-12 12:40:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RjJEb2/oJn9vWYvSjdWMCw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
