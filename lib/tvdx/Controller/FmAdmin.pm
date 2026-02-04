package tvdx::Controller::FmAdmin;
use Moose;
use Email::Address;
use Regexp::Common;
use DateTime;
use DateTime::Format::MySQL;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in tvdx.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

tvdx::Controller::FmAdmin - Catalyst FM AdminController for FM DX

=head1 DESCRIPTION

Functions for administering FM DX

=head1 METHODS

=cut


=head2 fm_admin_form

Display form to create or update user account for FM tuners

=cut


sub fm_admin_form :Global {
  my ($self, $c) = @_;

  unless ($c->stash->{accounts_found}) {
    $c->stash(accounts_found => [{tuner_key=>'', email=>'', user=>'', password=>'',
                user_description=>'', latitude=>'', longitude=>'', tuner_description => ''}],
              message => 'Fill in all fields except Tuner ID when creating new accounts (a new ID will be created).  Search on any field(s) except latitude and longitude to find existing accounts to edit.');
  }
  $c->stash({static_url=>$c->config->{static_url}, template=>'Root/fm_admin_form.tt', current_view=>'HTML'});
}


=head2 fm_admin_do

Process fm_admin_form data

=cut

sub fm_admin_form_do :Global :ActionClass('REST') {}

sub fm_admin_form_do_POST :Global {
  my ($self, $c) = @_;
  my $tuner_key = $c->request->params->{'tuner_key'};
  my $email = $c->request->params->{'email'};
  my $user = $c->request->params->{'user'};
  my $password = $c->request->params->{'password'};
  my $user_description = $c->request->params->{'user_description'};
  my $latitude = $c->request->params->{'latitude'};
  my $longitude = $c->request->params->{'longitude'};
  my $tuner_description = $c->request->params->{'tuner_description'};
  my $fm_admin_pw = $c->request->params->{'fm_admin_pw'};
  my $action = $c->request->params->{'submit'};
  
  if ($fm_admin_pw ne $c->config->{fm_admin_pw}) {
    $c->response->body("Wrong admin password.  Navigate back and try again");
    $c->response->status(400);
    $c->detach;
  }

  if ($action eq 'New') {
    _check_form_data($self,$c);

    # insert and display email text with new user_key and details
    my $user_db = $c->model('DB::FmUser')->create( { user => $user,
       password => $password, email => $email, description => $user_description });

    my $tuner_db = $c->model('DB::FmTuner')->create(
     { description => $tuner_description,
       user_key => $user_db->user_key,
       start_date => DateTime::Format::MySQL->format_datetime(DateTime->now),
       latitude => $latitude,
       longitude => $longitude,
       latlon => {latitude => $latitude, longitude => $longitude} });

    my $new_user_key = $tuner_db->tuner_key;
    my $new_user_url = $c->config->{root_url} . "/fm_one_tuner_map/$new_user_key";
    my $installer_url = $c->config->{static_url} . '/fmdx_install.exe';
    my $text = <<"EOTEXT";
New user ID $new_user_key, password $password created.
FM stations detected by the tuner will be shown at
<a href=\"$new_user_url\">$new_user_url</a> 
EOTEXT
    $c->response->body($text);
    $c->response->status(200);
    return;
  }
  if ($action eq 'Search') {
    my $trs = 0;
    my @found;
    if ($tuner_key) {
      my $row = $c->model('DB::FmTuner')->find($tuner_key);
      if ($row) {
        push (@found,{tuner_key=>$row->tuner_key, email=>$row->user_key->email, user=>$row->user_key->user,
                      password=>$row->user_key->password, user_description=>$row->user_key->description,
                      latitude=>$row->latitude, longitude=>$row->longitude,
                      tuner_description => $row->description});
      }
    } elsif ($tuner_description) {
      $trs = $c->model('DB::FmTuner')->search({description => $tuner_description});
    } else {
      my %fields;
      $fields{'user_key.email'} = $email if $email;
      $fields{'user_key.user'} = $user if $user;
      $fields{'user_key.password'} = $password if $password;
      $fields{'user_key.description'} = $user_description if $user_description;
      if (scalar %fields) {
        $trs = $c->model('DB::FmTuner')->search(\%fields, { join => 'user_key', prefetch => 'user_key' });
      }
    }
    if ($trs) {
      while (my $row = $trs->next()) {
        push (@found,{tuner_key=>$row->tuner_key, email=>$row->user_key->email, user=>$row->user_key->user,
                      password=>$row->user_key->password, user_description=>$row->user_key->description,
                      latitude=>$row->latitude, longitude=>$row->longitude,
                      tuner_description => $row->description});
      }
    }
    unless (scalar @found) {
      $c->response->body("Nothing found.  Navigate back and try again");
      $c->response->status(200);
      $c->detach;
    }
    $c->stash({accounts_found => \@found, fm_admin_pw => $fm_admin_pw, template => 'Root/fm_admin_form.tt',
               message => 'You can not change User ID, latitude or longitude'});
    # have to manually forward with content-type also set or catalyst returns 415 error
    $c->response->content_type('text/html');
    $c->forward('tvdx::View::HTML');
    return;
  }
  if ($action eq 'Update') {
    _check_form_data($self,$c);

    my $trow = $c->model('DB::FmTuner')->find($tuner_key);
    unless ($trow) {
      $c->response->body('Invalid tuner ID');
      $c->response->status(400);
      $c->detach;
    }
    $trow->update({description=>$tuner_description});
    my $urow = $trow->user_key;
    $urow->update({email=>$email, user=>$user, password=>$password, description=>$user_description});
    $c->response->body("Tuner updated");
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
  push @fail_reason, 'email invalid' if ($p->{email} !~ /^$Email::Address::addr_spec$/);
  push @fail_reason, 'user name has invalid character or is too long' if ($p->{user} !~ /^[a-zA-Z0-9]{1,255}$/);
  push @fail_reason, 'password too long' if ($p->{password} !~ /^.{1,8}$/);
  push @fail_reason, 'location too long' if ($p->{user_description} !~ /^.{1,255}$/);
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
