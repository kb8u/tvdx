package tvdx::Schema::ResultSet::SignalReport;
    
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use DateTime;
use DateTime::Format::MySQL;

=head2 all_last_24

Finds all signal reports from anybody in the last 24 hours.

=cut

sub all_last_24 {
  my ($self) = @_;

  my $last_24_hr = DateTime->from_epoch( epoch => time-86400 );
  my $end = DateTime::Format::MySQL->format_datetime($last_24_hr);
  return $self->search({ rx_date => { '>=' => $end },
                         'me.callsign' => { '!=', undef} },
                       { prefetch => ['tuner','callsign'] });
}
 

=head2 tuner_date_range

Finds all signal reports for a tuner that were between a start and end time.
times must be in DateTime format.
    
=cut
    
sub tuner_date_range {
  my ($self, $tuner_id, $tuner_number, $dt_start, $dt_end) = @_;
    
  my $start = DateTime::Format::MySQL->format_datetime($dt_start);
  my $end   = DateTime::Format::MySQL->format_datetime($dt_end);

  return $self->search({
    tuner_id     => $tuner_id,
    tuner_number => $tuner_number,
    rx_date      => { '<=' => $end },
    rx_date      => { '>=' => $start }
  });
}


=head2 most_recent

Select the most recent report and city for each call sign
The goal in sql was:

select signal_report.*,fcc.city_state from signal_report
join fcc on signal_report.callsign=fcc.callsign
group by callsign having max(rx_date)
order by rx_date,strength,fcc.city_state;

=cut

sub most_recent {
  my ($self) = @_;

  return($self->search(
         undef,
         { prefetch => 'callsign',
           group_by => 'me.callsign having max(rx_date)',
           order_by => { -desc => [qw(rx_date strength callsign.city_state)] },
         } ));

}

1;
