use utf8;
package tvdx::Schema::Result::Tsid;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::Tsid

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

=head1 TABLE: C<tsid>

=cut

__PACKAGE__->table("tsid");

=head1 ACCESSORS

=head2 tsid_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 rx_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 tsid

  data_type: 'integer'
  is_nullable: 0

=head2 callsign

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "tsid_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "rx_date",
  { data_type => "timestamp", is_nullable => 0 },
  "tsid",
  { data_type => "integer", is_nullable => 0 },
  "callsign",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tsid_key>

=back

=cut

__PACKAGE__->set_primary_key("tsid_key");

=head1 RELATIONS

=head2 callsign

Type: belongs_to

Related object: L<tvdx::Schema::Result::Fcc>

=cut

__PACKAGE__->belongs_to(
  "callsign",
  "tvdx::Schema::Result::Fcc",
  { callsign => "callsign" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-06-10 21:26:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cp4MryJklDP1VQzy9yGUWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
