package tvdx::Controller::TvAdmin;
use Moose;
use Regexp::Common;
use DateTime;
use DateTime::Format::MySQL;
use Data::Dumper;
use DateTime;
use DateTime::Format::MySQL;
use Math::Round 'nearest';

BEGIN { extends 'Catalyst::Controller::REST' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in tvdx.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

tvdx::Controller::TvAdmin - Catalyst TV AdminController for TV live band scan

=head1 DESCRIPTION

Functions for administering TV live band scan tuners

=head1 METHODS

=cut


=head2 tv_admin_form

Display form to create or update user account for TV tuners

=cut


sub tv_admin_form :Global {
  my ($self, $c) = @_;

  unless ($c->stash->{tuners}) {
    $c->stash(tuners => [{tuner_number_key=>'', tuner_id=>'', tuner_number=>'', owner_id=>'', latitude=>'', longitude=>'', tuner_description => ''}],
              message => 'Fill in all fields when creating new accounts.  Search on any field(s) to find existing accounts to edit.');
  }
  $c->stash({static_url=>$c->config->{static_url}, template=>'Root/tv_admin_form.tt', current_view=>'HTML'});
}


=head2 tv_admin_do

Process tv_admin_form data

=cut

sub tv_admin_form_do :Global :ActionClass('REST') {}

sub tv_admin_form_do_POST :Global {
  my ($self, $c) = @_;
  my $tuner_number_key = $c->request->params->{'tuner_number_key'};
  my $tuner_id = $c->request->params->{'tuner_id'};
  my $tuner_number = $c->request->params->{'tuner_number'};
  my $owner_id = $c->request->params->{'owner_id'};
  my $latitude = $c->request->params->{'latitude'};
  my $longitude = $c->request->params->{'longitude'};
  my $tuner_description = $c->request->params->{'tuner_description'};
  my $tv_admin_pw = $c->request->params->{'tv_admin_pw'};
  my $action = $c->request->params->{'submit'};
  
  unless (defined $tv_admin_pw && $tv_admin_pw eq $c->config->{fm_admin_pw}) {
    $c->response->body("Wrong admin password.  Navigate back and try again");
    $c->response->status(400);
    $c->detach;
  }

  if ($action eq 'New') {
    _check_form_data($self,$c);

    my $mysql_now = DateTime::Format::MySQL->format_datetime(DateTime->now);
    # create new row in tuner table
    my $tuner_row = $c->model('DB::Tuner')->create({tuner_id => $tuner_id, latitude => $latitude, 
       longitude => $longitude, owner_id => $owner_id, start_date => $mysql_now });

    # create new row in tuner_number table
    $c->model('DB::TunerNumber')->create({
       tuner_id => $tuner_row->tuner_id,
       tuner_number => $tuner_number,
       description => $tuner_description,
       start_date => $mysql_now});

    my $new_user_url = $c->config->{root_url} . "/tv_one_tuner_map/$tuner_id/$tuner_number";
    my $text = <<"EOTEXT";
New user created.  TV stations detected by the tuner will be shown at
$new_user_url 
EOTEXT
    $c->response->body($text);
    $c->response->status(200);
    return;
  }
  if ($action eq 'Search') {
    my $trs = 0;
    my @tuners;
    my %fields;
    $fields{'tuner_number'} = $tuner_number if $tuner_number;
    $fields{'description'} = $tuner_description if $tuner_description;
    $fields{'tuner.tuner_id'} = $tuner_id if $tuner_id;
    $fields{'tuner.latitude'} = $latitude if $latitude;
    $fields{'tuner.longitude'} = $longitude if $longitude;
    $fields{'tuner.owner_id'} = $owner_id if $owner_id;

    if (scalar %fields) {
      $trs = $c->model('DB::TunerNumber')->search(\%fields, { join => 'tuner', prefetch => 'tuner' });
    }
    if ($trs) {
      while (my $row = $trs->next()) {
        push (@tuners,{tuner_number_key=>$row->tuner_number_key,
                       tuner_id=>$row->tuner_id,
                       tuner_number=>$row->tuner_number,
                       owner_id=>$row->tuner->owner_id,
                       latitude=>nearest(.0001, $row->tuner->latitude),
                       longitude=>nearest(.0001, $row->tuner->longitude),
                       tuner_description=>$row->description});
      }
    }
    unless (scalar @tuners) {
      $c->response->body("Nothing found.  Navigate back and try again");
      $c->response->status(200);
      $c->detach;
    }
    $c->stash({tuners=>\@tuners, tv_admin_pw=>$tv_admin_pw, template=>'Root/tv_admin_form.tt',
               message=>'Edit any field (except tuner number) and click Update'});
    # have to manually forward with content-type also set or catalyst returns 415 error
    $c->response->content_type('text/html');
    $c->forward('tvdx::View::HTML');
    return;
  }
  if ($action eq 'Update') {
    _check_form_data($self,$c);
    my $trow = $c->model('DB::Tuner')->find($tuner_id);
    unless ($trow) {
      $c->response->body('Invalid tuner ID');
      $c->response->status(400);
      $c->detach;
    }
    $trow->update({owner_id=>$owner_id, latitude=>$latitude, longitude=> $longitude});

    my $tnrow = $c->model('DB::TunerNumber')->find($tuner_number_key);
    $tnrow->update({description=>$tuner_description});
    $c->response->body("Account settings have been changed");
    $c->response->status(200);
    $c->detach;
  }
  $c->response->body('Invalid form action');
  $c->response->status(200);
  $c->detach;
}


# check for valid data.  If invalid, show error page
sub _check_form_data {
  my ($self,$c) = @_;

  my @fail_reason;
  my $p = $c->request->params;
  push @fail_reason, 'location too long' if ($p->{owner_id} !~ /^.{1,255}$/);
  push @fail_reason, 'latitude (need decimal degrees)' if ($p->{latitude} !~ /^$RE{num}{real}$/);
  push @fail_reason, 'latitude too large' if ($p->{latitude} && $p->{latitude} > 72);
  push @fail_reason, 'latitude too small' if ($p->{latitude} && $p->{latitude} < 16);
  push @fail_reason, 'longitude (need decimal degrees)' if ($p->{longitude} !~ /^$RE{num}{real}$/);
  push @fail_reason, 'longitude too large (missing - sign?)' if ($p->{longitude} && $p->{longitude} > -52);
  push @fail_reason, 'longitude too small' if ($p->{longitude} && $p->{longitude} < -167);
  push @fail_reason, 'tuner description too long' if ($p->{tuner_description} !~ /^.{1,255}$/);
  if (@fail_reason) {
    my $text = "Error in field(s): " . (join ', ', @fail_reason) .  '.  Navigate back, fix the problems and then resubmit';
    $c->response->body($text);
    $c->response->status(400);
    $c->detach;
  }
}


=head2 end

Attempt to render a view, if needed.

=cut

#sub end :ActionClass('RenderView') {}
sub end : Private {
    my ( $self, $c ) = @_;
    $c->forward('tvdx::View::HTML') unless $c->response->output;
}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2021 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
