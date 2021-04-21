package tvdx::Controller::FmAdmin;
use Moose;
use Email::Address;
use Regexp::Common;
use DateTime;
use DateTime::Format::MySQL;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' }

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

  $c->stash(static_url => $c->config->{static_url});
  $c->stash(next_user_key =>
    $c->model('DB::FmTuner')->get_column('tuner_key')->max() + 1);
  $c->stash(template => 'Root/fm_admin_form.tt');
  $c->stash(current_view => 'HTML');
}


=head2 fm_admin_do

Process fm_admin_form data

=cut

sub fm_admin_form_do :Global {
  my ($self, $c) = @_;

  my $email = $c->request->params->{'email'};
  my $user = $c->request->params->{'user'};
  my $password = $c->request->params->{'password'};
  my $user_description = $c->request->params->{'user_description'};
  my $latitude = $c->request->params->{'latitude'};
  my $longitude = $c->request->params->{'longitude'};
  my $tuner_description = $c->request->params->{'tuner_description'};
  my $fm_admin_pw = $c->request->params->{'fm_admin_pw'};

  # check for valid data.  If invalid, show error page
  my @fail_reason;
  push @fail_reason, 'email' if ($email !~ /^$Email::Address::addr_spec$/);
  push @fail_reason, 'user name' if ($user !~ /^[a-zA-Z0-9]{1,255}$/);
  push @fail_reason, 'password' if ($password !~ /^.{1,255}$/);
  push @fail_reason, 'user description' if ($user_description !~ /^.{1,255}$/);
  push @fail_reason, 'latitude (need decimal degrees)' if ($latitude !~ /^$RE{num}{real}$/);
  push @fail_reason, 'latitude too large' if ($latitude && $latitude > 72);
  push @fail_reason, 'latitude too small' if ($latitude && $latitude < 16);
  push @fail_reason, 'longitude (need decimal degrees)' if ($longitude !~ /^$RE{num}{real}$/);
  push @fail_reason, 'longitude too large (missing - sign?)' if ($longitude && $longitude > -52);
  push @fail_reason, 'longitude too small' if ($longitude && $longitude < -167);
  push @fail_reason, 'tuner description' if ($tuner_description !~ /^.{1,255}$/);
  push @fail_reason, 'bad admin password' if ($fm_admin_pw ne $c->config->{fm_admin_pw});
  if (@fail_reason) {
    # Couldn't use tt here, always got a 415 error. Catalyst::Controller
    # apparently won't let you use tt with POST. Can't figure out work-around
    my $text = "Error in field(s): " . (join ', ', @fail_reason) .  '.  Navigate back, fix the problems and then resubmit';
    $c->response->body($text);
    $c->response->status(400);
    $c->detach;
  }

  # insert and display email text with new user_key and details
  my $user_db = $c->model('DB::FmUser')->create( { user => $user,
password => $password, email => $email, description => $user_description });

  my $tuner_db = $c->model('DB::FmTuner')->create(
   { description => $tuner_description,
     user_key => $user_db->user_key,
     start_date => DateTime::Format::MySQL->format_datetime(DateTime->now),
     latitude => $latitude,
     longitude => $longitude });

  my $new_user_key = $tuner_db->tuner_key;
  my $new_user_url = $c->config->{root_url} . "/fm_one_tuner_map/$new_user_key";  my $installer_url = $c->config->{static_url} . '/fmdx_install.exe';
  my $text = <<"EOTEXT";
New user $user, password $password created.

The windows installer is at <a href=\"$installer_url\">$installer_url</a>.  You
will need to enter the user ID number $new_user_key when you install the program.

Once installed, FM stations detected by the tuner will be shown at
<a href=\"$new_user_url\">$new_user_url</a> 
EOTEXT
  $c->response->body($text);
  $c->response->status(200);
}


=head2 end

Attempt to render a view, if needed.

=cut

#sub end : ActionClass('RenderView') {}


=head1 AUTHOR

Russell J Dwarshuis

=head1 LICENSE

Copyright 2021 by Russell Dwarshuis.
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
