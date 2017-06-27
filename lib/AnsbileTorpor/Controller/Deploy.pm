use 5.22.0;

package AnsbileTorpor::Controller::Deploy;

use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

AnsbileTorpor::Controller::Deploy

=cut

use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace

use AnsbileTorpor;

=head2 any

Runs the Ansible-playbooks relevant to the given inventory_hostname.
Building, reconfiguring and upgrading changes or even rebuilding the complete infrastructure if need be.

=cut

sub any {
  my $c = shift;
  my $status = 200;
  my ($cmd, $playbookParams, $exitValue, $error_message, $full_buf, $stdout_buf, $stderr_buf);
  eval {
    my $action = 'deploy';
    my $inventory_hostname = $c->param('inventory_hostname');

    my $playbookParams = $c->app->getDispatchRules($action, $inventory_hostname);
    ( $exitValue, $error_message, $full_buf, $stdout_buf, $stderr_buf, $cmd ) = $c->app->dispatchAnsiblePlaybook($playbookParams);
    $c->app->log->warn("ANSIBLE CMD:$cmd  ---  EXIT VALUE: $exitValue");

    $status = 500 if $exitValue;
  };
  if ($@) {
    return $c->render(status => 403, text => $@) if $@ =~ /Forbidden (?:inventory_hostname|action)/;
    return $c->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
  else {
    return $c->render(status => $status, text => "ANSIBLE COMMAND:\n$cmd\nSTDOUT:\n".join("\n", @$stdout_buf)."\nSTDERR:\n".join("\n",@$stderr_buf)."\nEXIT VALUE: $exitValue");
  }
}

1;
