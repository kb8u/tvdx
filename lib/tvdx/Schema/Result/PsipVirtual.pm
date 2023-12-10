use utf8;
package tvdx::Schema::Result::PsipVirtual;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::PsipVirtual

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

=head1 TABLE: C<psip_virtual>

=cut

__PACKAGE__->table("psip_virtual");

=head1 ACCESSORS

=head2 virtual_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 rx_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 program

  data_type: 'integer'
  is_nullable: 1

=head2 name

  data_type: 'tinyblob'
  is_nullable: 0

=head2 channel

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 callsign

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "virtual_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "rx_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "program",
  { data_type => "integer", is_nullable => 1 },
  "name",
  { data_type => "tinyblob", is_nullable => 0 },
  "channel",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "callsign",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</virtual_key>

=back

=cut

__PACKAGE__->set_primary_key("virtual_key");

=head1 RELATIONS

=head2 callsign

Type: belongs_to

Related object: L<tvdx::Schema::Result::Fcc>

=cut

__PACKAGE__->belongs_to(
  "callsign",
  "tvdx::Schema::Result::Fcc",
  { callsign => "callsign" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-12-10 16:58:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:puPT5wqmCK7teTLH9YCMVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
