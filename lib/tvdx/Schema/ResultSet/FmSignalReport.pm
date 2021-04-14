package tvdx::Schema::ResultSet::FmSignalReport;
    
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
                         'me.fcc_key' => { '!=', undef} },
                       { prefetch => ['fcc_key','tuner_key'] });
}
 

=head2 tuner_date_range

Finds all signal reports for a tuner that were between a start and end time.
times must be in DateTime format.
    
=cut
    
sub tuner_date_range {
  my ($self, $tuner_key, $dt_start, $dt_end) = @_;
    
  my $start = DateTime::Format::MySQL->format_datetime($dt_start);
  my $end   = DateTime::Format::MySQL->format_datetime($dt_end);

  return $self->search({
    tuner_key  => $tuner_key,
    rx_date    => { '<=' => $end },
    rx_date    => { '>=' => $start }
  });
}


=head2 most_recent

Select the most recent report and city for each call sign
The goal in sql was:

select fm_signal_report.*,fm_fcc.callsign,fm_fcc.city_state
from fm_signal_report
join fm_fcc on fm_signal_report.fcc_key=fm_fcc.fcc_key
group by fm_fcc.fcc_key having max(rx_date)
order by rx_date,strength,fm_fcc.city_state;

=cut

sub most_recent {
  my ($self) = @_;

  return($self->search(
         undef,
         { prefetch => 'fcc_key', 
           group_by => 'me.fcc_key having max(rx_date)',
           order_by => { -desc => [qw(rx_date strength fcc_key.city_state)] },
         } )
  );
}

1;
