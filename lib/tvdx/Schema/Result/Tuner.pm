use utf8;
package tvdx::Schema::Result::Tuner;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::Tuner

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<tuner>

=cut

__PACKAGE__->table("tuner");

=head1 ACCESSORS

=head2 tuner_id

  data_type: 'text'
  is_nullable: 0

=head2 latitude

  data_type: 'real'
  is_nullable: 0

=head2 longitude

  data_type: 'real'
  is_nullable: 0

=head2 owner_id

  data_type: 'text'
  is_nullable: 0

=head2 start_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 end_date

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tuner_id",
  { data_type => "text", is_nullable => 0 },
  "latitude",
  { data_type => "real", is_nullable => 0 },
  "longitude",
  { data_type => "real", is_nullable => 0 },
  "owner_id",
  { data_type => "text", is_nullable => 0 },
  "start_date",
  { data_type => "timestamp", is_nullable => 0 },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_id>

=back

=cut

__PACKAGE__->set_primary_key("tuner_id");

=head1 RELATIONS

=head2 signals

Type: has_many

Related object: L<tvdx::Schema::Result::Signal>

=cut

__PACKAGE__->has_many(
  "signals",
  "tvdx::Schema::Result::Signal",
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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-25 10:07:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1/pvZthAECUf0AF2V7BIPw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
