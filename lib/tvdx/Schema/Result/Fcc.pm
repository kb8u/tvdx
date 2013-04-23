package tvdx::Schema::Result::Fcc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 NAME

tvdx::Schema::Result::Fcc

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


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2011-01-13 21:09:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oP7zlBslh/rwLzbQEhnUSA

1;
