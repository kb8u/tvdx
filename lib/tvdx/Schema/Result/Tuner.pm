package tvdx::Schema::Result::Tuner;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 NAME

tvdx::Schema::Result::Tuner

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


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2011-01-13 21:09:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zT6CRWWsqBoyRqsVo9LqCA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
