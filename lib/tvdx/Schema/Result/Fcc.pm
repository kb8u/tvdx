use utf8;
package tvdx::Schema::Result::Fcc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::Fcc

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

=head1 TABLE: C<fcc>

=cut

__PACKAGE__->table("fcc");

=head1 ACCESSORS

=head2 callsign

  data_type: 'text'
  is_nullable: 0

=head2 rf_channel

  data_type: 'integer'
  is_nullable: 0

=head2 latitude

  data_type: 'real'
  is_nullable: 0

=head2 longitude

  data_type: 'real'
  is_nullable: 0

=head2 start_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 end_date

  data_type: 'timestamp'
  is_nullable: 1

=head2 virtual_channel

  data_type: 'real'
  is_nullable: 0

=head2 city_state

  data_type: 'text'
  is_nullable: 0

=head2 erp_kw

  data_type: 'real'
  is_nullable: 0

=head2 rcamsl

  data_type: 'real'
  is_nullable: 0

=head2 last_fcc_lookup

  data_type: 'timestamp'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "callsign",
  { data_type => "text", is_nullable => 0 },
  "rf_channel",
  { data_type => "integer", is_nullable => 0 },
  "latitude",
  { data_type => "real", is_nullable => 0 },
  "longitude",
  { data_type => "real", is_nullable => 0 },
  "start_date",
  { data_type => "timestamp", is_nullable => 0 },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
  "virtual_channel",
  { data_type => "real", is_nullable => 0 },
  "city_state",
  { data_type => "text", is_nullable => 0 },
  "erp_kw",
  { data_type => "real", is_nullable => 0 },
  "rcamsl",
  { data_type => "real", is_nullable => 0 },
  "last_fcc_lookup",
  { data_type => "timestamp", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</callsign>

=back

=cut

__PACKAGE__->set_primary_key("callsign");

=head1 RELATIONS

=head2 signals

Type: has_many

Related object: L<tvdx::Schema::Result::Signal>

=cut

__PACKAGE__->has_many(
  "signals",
  "tvdx::Schema::Result::Signal",
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

=head2 virtuals

Type: has_many

Related object: L<tvdx::Schema::Result::Virtual>

=cut

__PACKAGE__->has_many(
  "virtuals",
  "tvdx::Schema::Result::Virtual",
  { "foreign.callsign" => "self.callsign" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-06-10 21:26:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yiXeIQPys4veLvSpUNUlNA

1;
