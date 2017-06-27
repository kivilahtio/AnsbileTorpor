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

use IPC::Cmd;

=head2 any

Runs the Ansible-playbooks relevant to the given inventory_hostname.
Building, reconfiguring and upgrading changes or even rebuilding the complete infrastructure if need be.

=cut

sub any {
  my $c = shift;
  my $status = 200;
  my ($cmd, $success, $error_message, $full_buf, $stdout_buf, $stderr_buf);
  eval {
    my $inventory_hostname = $c->param('inventory_hostname');
    my $config = $c->config();

    _checkAllowedInventoryHostname($c, $config, $inventory_hostname);
    $cmd = _getAnsibleDeployCommand($inventory_hostname, $config);

    #Ansible scripts will propably take some time
    $c->app->log->warn('ANSIBLE CMD:'.$cmd);

    ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
            IPC::Cmd::run( command => $cmd, verbose => 0 );
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    $status = 500 if $ansbile_out_rv || not($success);
  };
  if ($@) {
    return $c->render(status => 403, text => $@) if $@ =~ /not in the allowed inventory/;
    return $c->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
  else {
    return $c->render(status => $status, text => "ANSIBLE COMMAND:\n$cmd\nSTDOUT:\n".join("\n", @$stdout_buf)."\nSTDERR:\n".join("\n",@$stderr_buf));
  }
}

=head2 _checkAllowedInventoryHostname

dies with an error message if inventory_hostname is not allowed to be ran tests on

=cut

sub _checkAllowedInventoryHostname {
  my ($c, $config, $inventory_hostname) = @_;
  #warn Data::Dumper::Dumper($config);
  unless ($config->{allowed_deploy_inventory_hostnames}->{ $inventory_hostname }) {
    my @aih = keys %{$config->{allowed_deploy_inventory_hostnames}};
    die "\$inventory_hostname '$inventory_hostname' not in the allowed inventory hostnames list '@aih'";
  }
}

sub _getAnsibleDeployCommand {
  my ($inventory_hostname, $config) = @_;
  my $ansible_home = $config->{ansible_home};
  my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
  my $lxc_host = $config->{lxc_host};
  #Does this subroutine make any sense?
  if    ($inventory_hostname =~ /^koha/) {
    return "cd $ansible_home && $ansible_playbook_cmd -i production.inventory -l '$inventory_hostname,$lxc_host'  -e 'target=$inventory_hostname' everything.playbook";
  }
  elsif ($inventory_hostname =~ /^hetula/) {
    return "cd $ansible_home && $ansible_playbook_cmd -i production.inventory -l '$inventory_hostname,$lxc_host'  -e 'target=$inventory_hostname' everything.playbook";
  }
  else {
    return "cd $ansible_home && $ansible_playbook_cmd -i production.inventory -l '$inventory_hostname,$lxc_host'  -e 'target=$inventory_hostname' everything.playbook";
  }
}

1;

