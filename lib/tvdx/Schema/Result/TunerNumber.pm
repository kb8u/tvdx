use utf8;
package tvdx::Schema::Result::TunerNumber;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::TunerNumber

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

=head1 TABLE: C<tuner_number>

=cut

__PACKAGE__->table("tuner_number");

=head1 ACCESSORS

=head2 tuner_number_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tuner_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 tuner_number

  data_type: 'text'
  is_nullable: 0

=head2 description

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
  "tuner_number_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tuner_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "tuner_number",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "start_date",
  { data_type => "timestamp", is_nullable => 0 },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tuner_number_key>

=back

=cut

__PACKAGE__->set_primary_key("tuner_number_key");

=head1 RELATIONS

=head2 tuner

Type: belongs_to

Related object: L<tvdx::Schema::Result::Tuner>

=cut

__PACKAGE__->belongs_to(
  "tuner",
  "tvdx::Schema::Result::Tuner",
  { tuner_id => "tuner_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-25 10:07:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JQXtN/4kPjfMuF29x4hfBg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
