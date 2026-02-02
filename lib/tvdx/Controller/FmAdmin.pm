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
    $c->stash(accounts_found => [{tuner_id=>'', email=>'', user=>'', password=>'', user_description=>'',
                   latitude=>'', longitude=>'', tuner_description => ''}]);
  }
  $c->stash({static_url=>$c->config->{static_url}, template=>'Root/fm_admin_form.tt', current_view=>'HTML'});
}


=head2 fm_admin_do

Process fm_admin_form data

=cut

sub fm_admin_form_do :Global :ActionClass('REST') {}

sub fm_admin_form_do_POST :Global {
  my ($self, $c) = @_;
$c->log->debug("content-type: ".$c->request->header('Content-Type'));
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
    # check for valid data.  If invalid, show error page
    my @fail_reason;
    push @fail_reason, 'email invalid' if ($email !~ /^$Email::Address::addr_spec$/);
    push @fail_reason, 'user name has invalid character or is too long' if ($user !~ /^[a-zA-Z0-9]{1,255}$/);
    push @fail_reason, 'password too long' if ($password !~ /^.{1,8}$/);
    push @fail_reason, 'user description too long' if ($user_description !~ /^.{1,255}$/);
    push @fail_reason, 'latitude (need decimal degrees)' if ($latitude !~ /^$RE{num}{real}$/);
    push @fail_reason, 'latitude too large' if ($latitude && $latitude > 72);
    push @fail_reason, 'latitude too small' if ($latitude && $latitude < 16);
    push @fail_reason, 'longitude (need decimal degrees)' if ($longitude !~ /^$RE{num}{real}$/);
    push @fail_reason, 'longitude too large (missing - sign?)' if ($longitude && $longitude > -52);
    push @fail_reason, 'longitude too small' if ($longitude && $longitude < -167);
    push @fail_reason, 'tuner description too long' if ($tuner_description !~ /^.{1,255}$/);
    if (@fail_reason) {
      # to use tt here, see error about 415 below
      my $text = "Error in field(s): " . (join ', ', @fail_reason) .  '.  Navigate back, fix the problems and then resubmit';
      $c->response->body($text);
      $c->response->status(400);
      return;
    }

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

The windows installer is at <a href=\"$installer_url\">$installer_url</a>.  You
will need to enter the user ID number $new_user_key when you install the program.

Once installed, FM stations detected by the tuner will be shown at
<a href=\"$new_user_url\">$new_user_url</a> 
EOTEXT
    $c->response->body($text);
    $c->response->status(200);
    return;
  }
  if ($action eq 'Search') {
    # search and render results into same form
    my $trs = 0;
    my @found;
    if ($tuner_key) {
      $trs = $c->model('DB::FmTuner')->find($tuner_key);
    } elsif ($tuner_description) {
      $trs = $c->model('DB::FmTuner')->search({description => $tuner_description});
    } else {
      my %fields;
      $fields{'user_key.email'} = $email if $email;
      $fields{'user_key.description'} = $user_description if $user_description;
      if (scalar %fields) {
        $trs = $c->model('DB::FmTuner')->search(\%fields, { join => 'user_key', prefetch => 'user_key' });
      }
    }
    while (my $row = $trs->next()) {
      push (@found,{tuner_id=>$row->tuner_key, email=>$row->user_key->email, user=>$row->user_key->user,
                    password=>$row->user_key->password, user_description=>$row->user_key->description,
                    latitude=>$row->latitude, longitude=>$row->longitude,
                    tuner_description => $row->description});
    }
    $c->stash(accounts_found => \@found);
    $c->stash(template => 'Root/fm_admin_form.tt');
    # have to manually forward with content-type also set or catalyst returns 415 error
    $c->response->content_type('text/html');
    $c->forward('tvdx::View::HTML');
    return;
  }
  if ($action eq 'Update') {
    # update
    return;
  }
  $c->response->body('Invalid form action');
  $c->response->status(200);
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
