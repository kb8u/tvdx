package tvdx::Controller::FmLogin;
use Moose;
use strict;
use warnings;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in tvdx.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

tvdx::Controller::FmAdmin 

=head1 DESCRIPTION

Login and logout functions for FM DX map

=head1 METHODS

=cut

=head2 show_permissions

Display what permissions are authorized for a user ID
or an error message if theer are none.

=cut

sub show_permissions : Local {
  my ($self, $c) = @_;

  my $user = $c->user->user_key;
  unless (defined $user) {
    $c->response->body("User is not logged in");
    $c->response->status(401);
    return;
  }
  $c->stash(template     => 'Root/show_permissions.tt');
  $c->stash(current_view => 'HTML');
  $c->stash(expires => scalar localtime $c->session_expires());
  $c->stash(user => $user);
  $c->stash(permissions => $c->user->permissions);
}


=head2 login_form

Display form to log in

=cut

sub login_form : Local {
    my ($self, $c) = @_;
    # Renders an HTML login form template
    $c->stash(template => 'Root/login.tt');
    $c->stash(current_view => 'HTML');

}


=head2 login

Check database to authenticate user or not.

=cut

sub login : Local {
  my ($self, $c) = @_;
  my ($user, $password) = ($c->req->param('user'), $c->req->param('password'));

  my $tuner = $c->model('DB::FmTuner')->find({'tuner_key'=>$user});
  if (! $tuner) {
    $c->response->body("FAIL: Tuner $user is not registered with site");
    $c->response->status(403);
    $c->detach();
  }

  if ($c->authenticate({ user_key => $tuner->user_key->user_key, password => $password })) {
    $c->log->debug("User $user authenticated");
    $c->response->redirect($c->uri_for("/fm_one_tuner_map/$user"));
  } else {
    $c->log->debug("User $user failed to authenticate");
    $c->response->body("FAIL: Tuner $user wrong password.  Go back and try again.");
    $c->response->status(403);
    $c->detach();
  }
}

=head2 logout

Logout user

=cut

sub logout : Local {
    my ($self, $c) = @_;
    $c->logout;
    $c->response->redirect($c->uri_for('/'));
}
