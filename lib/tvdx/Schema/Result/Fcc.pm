use utf8;
package tvdx::Schema::Result::Fcc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::Fcc

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

=head1 TABLE: C<fcc>

=cut

__PACKAGE__->table("fcc");

=head1 ACCESSORS

=head2 callsign

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 rf_channel

  data_type: 'integer'
  is_nullable: 0

=head2 latitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 longitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 start_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 end_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 virtual_channel

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 city_state

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 erp_kw

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 rcamsl

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 last_fcc_lookup

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "callsign",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "rf_channel",
  { data_type => "integer", is_nullable => 0 },
  "latitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "longitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "start_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "end_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "virtual_channel",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "city_state",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "erp_kw",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "rcamsl",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "last_fcc_lookup",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</callsign>

=back

=cut

__PACKAGE__->set_primary_key("callsign");

=head1 RELATIONS

=head2 psip_virtuals

Type: has_many

Related object: L<tvdx::Schema::Result::PsipVirtual>

=cut

__PACKAGE__->has_many(
  "psip_virtuals",
  "tvdx::Schema::Result::PsipVirtual",
  { "foreign.callsign" => "self.callsign" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 signal_reports

Type: has_many

Related object: L<tvdx::Schema::Result::SignalReport>

=cut

__PACKAGE__->has_many(
  "signal_reports",
  "tvdx::Schema::Result::SignalReport",
  { "foreign.callsign" => "self.callsign" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tsids

Type: has_many

Related object: L<tvdx::Schema::Result::Tsid>

=cut

__PACKAGE__->has_many(
  "tsids",
  "tvdx::Schema::Result::Tsid",
  { "foreign.callsign" => "self.callsign" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2018-07-09 16:00:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F9hq6WSjO6DyLeIDUZkSyQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
