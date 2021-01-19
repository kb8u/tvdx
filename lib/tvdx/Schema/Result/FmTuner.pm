use utf8;
package tvdx::Schema::Result::FmTuner;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::FmTuner

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

=head1 TABLE: C<fm_tuner>

=cut

__PACKAGE__->table("fm_tuner");

=head1 ACCESSORS

=head2 tuner_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 user_key

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 start_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 end_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 latitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 longitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=cut

__PACKAGE__->add_columns(
  "tuner_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "user_key",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  "latitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "longitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_key>

=back

=cut

__PACKAGE__->set_primary_key("tuner_key");

=head1 RELATIONS

=head2 fm_signal_reports

Type: has_many

Related object: L<tvdx::Schema::Result::FmSignalReport>

=cut

__PACKAGE__->has_many(
  "fm_signal_reports",
  "tvdx::Schema::Result::FmSignalReport",
  { "foreign.tuner_key" => "self.tuner_key" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_key

Type: belongs_to

Related object: L<tvdx::Schema::Result::FmUser>

=cut

__PACKAGE__->belongs_to(
  "user_key",
  "tvdx::Schema::Result::FmUser",
  { user_key => "user_key" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2021-01-19 14:05:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Xgj1UKTB0o0IqMVGpP8J1A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
