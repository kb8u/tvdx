use utf8;
package tvdx::Schema::Result::Tuner;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::Tuner

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

=head1 TABLE: C<tuner>

=cut

__PACKAGE__->table("tuner");

=head1 ACCESSORS

=head2 tuner_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 latitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 longitude

  data_type: 'float'
  is_nullable: 0
  size: [11,8]

=head2 owner_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 start_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 end_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tuner_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "latitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "longitude",
  { data_type => "float", is_nullable => 0, size => [11, 8] },
  "owner_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
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
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_id>

=back

=cut

__PACKAGE__->set_primary_key("tuner_id");

=head1 RELATIONS

=head2 signal_reports

Type: has_many

Related object: L<tvdx::Schema::Result::SignalReport>

=cut

__PACKAGE__->has_many(
  "signal_reports",
  "tvdx::Schema::Result::SignalReport",
  { "foreign.tuner_id" => "self.tuner_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tuner_numbers

Type: has_many

Related object: L<tvdx::Schema::Result::TunerNumber>

=cut

__PACKAGE__->has_many(
  "tuner_numbers",
  "tvdx::Schema::Result::TunerNumber",
  { "foreign.tuner_id" => "self.tuner_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2018-07-09 16:00:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/QCyz5SdMl5z4kit75JCqw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
