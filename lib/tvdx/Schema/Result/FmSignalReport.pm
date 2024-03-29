use utf8;
package tvdx::Schema::Result::FmSignalReport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::FmSignalReport

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

=head1 TABLE: C<fm_signal_report>

=cut

__PACKAGE__->table("fm_signal_report");

=head1 ACCESSORS

=head2 signal_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 rx_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 first_rx_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 frequency

  data_type: 'integer'
  is_nullable: 0

=head2 tuner_key

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 fcc_key

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 strength

  data_type: 'decimal'
  is_nullable: 1
  size: [5,2]

=cut

__PACKAGE__->add_columns(
  "signal_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
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
  "frequency",
  { data_type => "integer", is_nullable => 0 },
  "tuner_key",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "fcc_key",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "strength",
  { data_type => "decimal", is_nullable => 1, size => [5, 2] },
);

=head1 PRIMARY KEY

=over 4

=item * L</signal_key>

=back

=cut

__PACKAGE__->set_primary_key("signal_key");

=head1 RELATIONS

=head2 fcc_key

Type: belongs_to

Related object: L<tvdx::Schema::Result::FmFcc>

=cut

__PACKAGE__->belongs_to(
  "fcc_key",
  "tvdx::Schema::Result::FmFcc",
  { fcc_key => "fcc_key" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 tuner_key

Type: belongs_to

Related object: L<tvdx::Schema::Result::FmTuner>

=cut

__PACKAGE__->belongs_to(
  "tuner_key",
  "tvdx::Schema::Result::FmTuner",
  { tuner_key => "tuner_key" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-12-11 20:09:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:88oGch4ZjYRe+DUF6uyr+w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;

use DateTime::Format::MySQL;
use DateTime::Format::HTTP;

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;


=head2 http_time

Return the time in HTTP format

=cut

sub http_time {
  my ($self) = @_;

  return DateTime::Format::HTTP->format_datetime(
           DateTime::Format::MySQL->parse_datetime($self->rx_date)
             ->set_time_zone('UTC')
         );
}

=head2 color

Return the popup color for a station based on receive time

=cut

sub color {
  my ($self) = @_;

  my $now = DateTime->now();
  my $r_dt = DateTime::Format::MySQL->parse_datetime($self->rx_date);

  return 'black' if $r_dt >= $now->subtract(minutes => 15);
  return 'dimgray' if $r_dt >= $now->subtract(minutes => 30);
  return 'darkgray';
}

1;
