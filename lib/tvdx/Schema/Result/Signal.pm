package tvdx::Schema::Result::Signal;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 NAME

tvdx::Schema::Result::Signal

=cut

__PACKAGE__->table("signal");

=head1 ACCESSORS

=head2 signal_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 rx_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 first_rx_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 rf_channel

  data_type: 'integer'
  is_nullable: 0

=head2 strength

  data_type: 'real'
  is_nullable: 0

=head2 sig_noise

  data_type: 'real'
  is_nullable: 0

=head2 tuner_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 tuner_number

  data_type: 'text'
  is_nullable: 0

=head2 callsign

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 virtual_channel

  data_type: 'real'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "signal_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "rx_date",
  { data_type => "timestamp", is_nullable => 0 },
  "first_rx_date",
  { data_type => "timestamp", is_nullable => 0 },
  "rf_channel",
  { data_type => "integer", is_nullable => 0 },
  "strength",
  { data_type => "real", is_nullable => 0 },
  "sig_noise",
  { data_type => "real", is_nullable => 0 },
  "tuner_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "tuner_number",
  { data_type => "text", is_nullable => 0 },
  "callsign",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "virtual_channel",
  { data_type => "real", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("signal_key");

=head1 RELATIONS

=head2 callsign

Type: belongs_to

Related object: L<tvdx::Schema::Result::Fcc>

=cut

__PACKAGE__->belongs_to(
  "callsign",
  "tvdx::Schema::Result::Fcc",
  { callsign => "callsign" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 tuner

Type: belongs_to

Related object: L<tvdx::Schema::Result::Tuner>

=cut

__PACKAGE__->belongs_to(
  "tuner",
  "tvdx::Schema::Result::Tuner",
  { tuner_id => "tuner_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2011-04-03 11:31:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oVzCSaaXddj/yW1v1odPxw

=head2 color

Returns 'red' for signal strength < 75
Returns 'yellow' for signal strentgh betwee 75 and 85
Returns 'green' for signal strength > 85

=cut

sub color {
  my ($self) = @_;

  return 'green' if $self->strength > 85;
  return 'yellow' if $self->strength > 75;
  return 'red';
}

1;
