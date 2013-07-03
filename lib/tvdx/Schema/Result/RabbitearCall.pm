use utf8;
package tvdx::Schema::Result::RabbitearCall;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

tvdx::Schema::Result::RabbitearCall

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

=head1 TABLE: C<rabbitears_call>

=cut

__PACKAGE__->table("rabbitears_call");

=head1 ACCESSORS

=head2 re_call_key

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 callsign

  data_type: 'text'
  is_nullable: 0

=head2 re_rval

  data_type: 'text'
  is_nullable: 1

=head2 last_re_lookup

  data_type: 'timestamp'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "re_call_key",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "callsign",
  { data_type => "text", is_nullable => 0 },
  "re_rval",
  { data_type => "text", is_nullable => 1 },
  "last_re_lookup",
  { data_type => "timestamp", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</re_call_key>

=back

=cut

__PACKAGE__->set_primary_key("re_call_key");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-07-02 21:34:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:URzojGKnVEBIFljTF4/nmA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
