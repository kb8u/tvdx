use utf8;
package tvdx::Schema::Result::PlpInfo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::PlpInfo

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

=head1 TABLE: C<plp_info>

=cut

__PACKAGE__->table("plp_info");

=head1 ACCESSORS

=head2 tuner_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 callsign

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 modulation

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 tuner_number

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 255

=head2 rf_channel

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 plp_id

  data_type: 'integer'
  is_nullable: 0

=head2 ti

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 sfi

  data_type: 'integer'
  is_nullable: 1

=head2 layer

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 lls

  data_type: 'integer'
  is_nullable: 1

=head2 cod

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 plp_lock

  data_type: 'integer'
  is_nullable: 1

=head2 plp_mod

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "tuner_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "callsign",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "modulation",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "tuner_number",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "rf_channel",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "plp_id",
  { data_type => "integer", is_nullable => 0 },
  "ti",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "sfi",
  { data_type => "integer", is_nullable => 1 },
  "layer",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "lls",
  { data_type => "integer", is_nullable => 1 },
  "cod",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "plp_lock",
  { data_type => "integer", is_nullable => 1 },
  "plp_mod",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_id>

=item * L</callsign>

=item * L</modulation>

=item * L</tuner_number>

=item * L</rf_channel>

=item * L</plp_id>

=back

=cut

__PACKAGE__->set_primary_key(
  "tuner_id",
  "callsign",
  "modulation",
  "tuner_number",
  "rf_channel",
  "plp_id",
);

=head1 RELATIONS

=head2 signal_report

Type: belongs_to

Related object: L<tvdx::Schema::Result::SignalReport>

=cut

__PACKAGE__->belongs_to(
  "signal_report",
  "tvdx::Schema::Result::SignalReport",
  {
    callsign     => "callsign",
    modulation   => "modulation",
    rf_channel   => "rf_channel",
    tuner_id     => "tuner_id",
    tuner_number => "tuner_number",
  },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-06 10:42:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AYy25/bVinjKOm1f7VQ3pQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
