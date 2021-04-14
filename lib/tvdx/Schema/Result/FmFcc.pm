use utf8;
package tvdx::Schema::Result::FmFcc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::FmFcc

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

=head1 TABLE: C<fm_fcc>

=cut

__PACKAGE__->table("fm_fcc");

=head1 ACCESSORS

=head2 fcc_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 callsign

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 relay_of

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 frequency

  data_type: 'integer'
  is_nullable: 0

=head2 city_state

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 country

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 mode

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 lang

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 format

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 slogan

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 erp_h

  data_type: 'decimal'
  is_nullable: 1
  size: [7,3]

=head2 erp_v

  data_type: 'decimal'
  is_nullable: 1
  size: [7,3]

=head2 haat_h

  data_type: 'decimal'
  is_nullable: 1
  size: [5,1]

=head2 haat_v

  data_type: 'decimal'
  is_nullable: 1
  size: [5,1]

=head2 latitude

  data_type: 'decimal'
  is_nullable: 0
  size: [6,3]

=head2 longitude

  data_type: 'decimal'
  is_nullable: 0
  size: [6,3]

=head2 pi_code

  data_type: 'integer'
  is_nullable: 1

=head2 ps_info

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 radiotext

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pty

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 remarks

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 start_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 end_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 last_fcc_lookup

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "fcc_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "callsign",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "relay_of",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "frequency",
  { data_type => "integer", is_nullable => 0 },
  "city_state",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "country",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "mode",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "lang",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "format",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "slogan",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "erp_h",
  { data_type => "decimal", is_nullable => 1, size => [7, 3] },
  "erp_v",
  { data_type => "decimal", is_nullable => 1, size => [7, 3] },
  "haat_h",
  { data_type => "decimal", is_nullable => 1, size => [5, 1] },
  "haat_v",
  { data_type => "decimal", is_nullable => 1, size => [5, 1] },
  "latitude",
  { data_type => "decimal", is_nullable => 0, size => [6, 3] },
  "longitude",
  { data_type => "decimal", is_nullable => 0, size => [6, 3] },
  "pi_code",
  { data_type => "integer", is_nullable => 1 },
  "ps_info",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "radiotext",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pty",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "remarks",
  { data_type => "varchar", is_nullable => 1, size => 255 },
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
  "last_fcc_lookup",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</fcc_key>

=back

=cut

__PACKAGE__->set_primary_key("fcc_key");

=head1 RELATIONS

=head2 fm_signal_reports

Type: has_many

Related object: L<tvdx::Schema::Result::FmSignalReport>

=cut

__PACKAGE__->has_many(
  "fm_signal_reports",
  "tvdx::Schema::Result::FmSignalReport",
  { "foreign.fcc_key" => "self.fcc_key" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2021-01-24 20:50:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ekxflzp/oQlE/Cdc9e2bzA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
