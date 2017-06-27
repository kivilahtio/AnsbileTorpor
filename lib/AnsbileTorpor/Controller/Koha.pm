use 5.22.0;

package AnsbileTorpor::Controller::Koha;

use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

AnsbileTorpor::Controller::Koha

=cut

use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace

use AnsbileTorpor;

use IPC::Cmd;

=head2 build

Runs the Ansible-playbooks relevant to the given inventory_hostname.
Building, reconfiguring and upgrading changes or even rebuilding the complete infrastructure if need be.

=cut

sub build {
  my $c = shift;
  my $status = 200;
  my ($cmd, $success, $error_message, $full_buf, $stdout_buf, $stderr_buf);
  eval {
    my $config = $c->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
    my $lxc_host = $config->{lxc_host};
    my $inventory_hostname = $c->param('inventory_hostname');

    _checkAllowedInventoryHostname($c, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    $cmd = "cd $ansible_home && $ansible_playbook_cmd -i production.inventory -l '$inventory_hostname,$lxc_host'  -e 'target=$inventory_hostname' everything.playbook";
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

=head2 alltest

Runs the Koha's big test suite and gathers other code quality metrics.
Tar's them up and sends them with the response.

=cut

sub alltest {
  my $c = shift;
  my $testSuite = 'all';
  _handleTest($c, $testSuite);
}

=head2 gittest

Runs Koha's git test suite.
Tar's them up and sends back with the response.

=cut

sub gittest {
  my $c = shift;
  my $testSuite = 'git';
  _handleTest($c, $testSuite);
}

=head2 _handleTest

Executes the Ansible playbook with correct parameters

$testSuite is one of the test suite parameters Koha/ks-test-harness.pl receives

=cut

sub _handleTest {
  my ($c, $testSuite) = @_;
  my $status = 200;
  my ($cmd, $success, $error_message, $full_buf, $stdout_buf, $stderr_buf);
  my $inventory_hostname = $c->param('inventory_hostname');
  eval {
    my $config = $c->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};

    _checkAllowedInventoryHostname($c, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    $cmd = "cd $ansible_home && $ansible_playbook_cmd -i production.inventory -l $inventory_hostname -e koha_run_tests=true -e koha_run_${testSuite}_tests=true application_koha.playbook";
    $c->app->log->warn('ANSIBLE CMD:'.$cmd);

    ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
            IPC::Cmd::run( command => $cmd, verbose => 0 );
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    if ($ansbile_out_rv || not($success)) {
      die "ERROR:\n$error_message\nOUTPUT(STDOUT/STDERR)\n".join("\n",@$full_buf);
    }
  };
  if ($@) {
    return $c->render(status => 403, text => $@) if $@ =~ /not in the allowed inventory/;
    return $c->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
  else {
    return $c->render(status => $status, text => "ANSIBLE COMMAND:\n$cmd\nSTDOUT:\n".join("\n", @$stdout_buf)."\nSTDERR:\n".join("\n",@$stderr_buf));

    #Ansible should put the test deliverables to /home/ansible/public/$inventory_hostname/testResults.tar.gz
    #User must download them afterwards with curl http://0.0.0.0/$inventory_hostname/testResults.tar.gz
    #return $c->reply->static("$inventory_hostname/testResults.tar.gz");
  }
}

=head2 _checkAllowedInventoryHostname

dies with an error message if inventory_hostname is not allowed to be ran tests on

=cut

sub _checkAllowedInventoryHostname {
  my ($c, $config, $inventory_hostname) = @_;
  unless ($config->{allowed_inventory_hostnames}->{ $inventory_hostname }) {
    my @aih = keys %{$config->{allowed_inventory_hostnames}};
    die "\$inventory_hostname '$inventory_hostname' not in the allowed inventory hostnames list '@aih'";
  }
}

1;

