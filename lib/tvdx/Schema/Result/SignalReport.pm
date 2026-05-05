use utf8;
package tvdx::Schema::Result::SignalReport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::SignalReport

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

=head1 TABLE: C<signal_report>

=cut

__PACKAGE__->table("signal_report");

=head1 ACCESSORS

=head2 rx_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 first_rx_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 rf_channel

  data_type: 'integer'
  is_nullable: 0

=head2 modulation

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 strength

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 sig_noise

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 tuner_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 tuner_number

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 callsign

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 virtual_channel

  data_type: 'float'
  is_nullable: 1
  size: [11,8]

=head2 l1detail

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "rx_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "first_rx_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "rf_channel",
  { data_type => "integer", is_nullable => 0 },
  "modulation",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "strength",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "sig_noise",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "tuner_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "tuner_number",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "callsign",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "virtual_channel",
  { data_type => "float", is_nullable => 1, size => [11, 8] },
  "l1detail",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_id>

=item * L</callsign>

=item * L</modulation>

=item * L</tuner_number>

=item * L</rf_channel>

=back

=cut

__PACKAGE__->set_primary_key(
  "tuner_id",
  "callsign",
  "modulation",
  "tuner_number",
  "rf_channel",
);

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

=head2 plp_infos

Type: has_many

Related object: L<tvdx::Schema::Result::PlpInfo>

=cut

__PACKAGE__->has_many(
  "plp_infos",
  "tvdx::Schema::Result::PlpInfo",
  {
    "foreign.callsign"     => "self.callsign",
    "foreign.modulation"   => "self.modulation",
    "foreign.rf_channel"   => "self.rf_channel",
    "foreign.tuner_id"     => "self.tuner_id",
    "foreign.tuner_number" => "self.tuner_number",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tuner

Type: belongs_to

Related object: L<tvdx::Schema::Result::Tuner>

=cut

__PACKAGE__->belongs_to(
  "tuner",
  "tvdx::Schema::Result::Tuner",
  { tuner_id => "tuner_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-05 12:13:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yBiAc4RjuhIDuXaV71loGg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;

=head2 color

Returns 'red' for signal strength < 75
Returns 'yellow' for signal strentgh between 75 and 85
Returns 'green' for signal strength > 85

=cut

sub color {
  my ($self) = @_;

  return 'green' if $self->strength > 85;
  return 'yellow' if $self->strength > 75;
  return 'red';
}

1;
