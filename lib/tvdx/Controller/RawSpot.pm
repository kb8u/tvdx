package tvdx::Controller::RawSpot;
use Moose;
use namespace::autoclean;
use DateTime;
use DateTime::Format::SQLite;
use DateTime::Format::HTTP;
use XML::Simple;
use LWP::Simple;
use RRDs;
use List::MoreUtils 'none';


BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

tvdx::Controller::RawSpot - Catalyst Controller

=head1 DESCRIPTION

Process Raw spots from clients.  These are spots that contain all the data
the tuner generates, not just stations that are coming in and one virtual
channel.

=head1 METHODS

=cut


=head2 raw_spot

Accept raw spots from client and convert into a data structure Perl can use.

=cut

sub raw_spot :Global {
  my ( $self, $c ) = @_;

  # the current time formatted to sqlite format (UTC time zone)
  my $sqlite_now = DateTime::Format::SQLite->format_datetime(DateTime->now);
  my $now_epoch = time;

  # xml with information from (client) scanlog.pl
This needs changing....
  my $href = XMLin($c->request->params->{'xml'}, ForceArray => ['tv_signal'] );


  $c->response->body('Woo-woo!');
}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2013 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
