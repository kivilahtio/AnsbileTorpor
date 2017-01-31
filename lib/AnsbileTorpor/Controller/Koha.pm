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


=head2 build

Runs the Ansible-playbooks relevant to the given inventory_hostname.
Building, reconfiguring and upgrading changes or even rebuilding the complete infrastructure if need be.

=cut

sub build {
  my $self = shift;
  eval {
    my $config = $self->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
    my $lxc_host = $config->{lxc_host};
    my $inventory_hostname = $self->param('inventory_hostname');

    return unless _checkAllowedInventoryHostname($self, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    my $ansbile_out = `cd $ansible_home && $ansible_playbook_cmd -i production -l $inventory_hostname -l $lxc_host everything.playbook`;
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    my $status = 200;
    $status = 500 if $ansbile_out_rv;
    $self->render(status => $status, text => $ansbile_out);
  };
  if ($@) {
    $self->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
}

=head2 test

Runs the Koha's big test suite and gathers other code quality metrics.
Tar's them up and sends them with the response.

=cut

sub test {
  my $self = shift;
  my $testSuite = 'all';
  _handleTest($self, $testSuite);
}

=head2 gittest

Runs Koha's git test suite.
Tar's them up and sends back with the response.

=cut

sub gittest {
  my $self = shift;
  my $testSuite = 'git';
  _handleTest($self, $testSuite);
}

=head2 _handleTest

Executes the Ansible playbook with correct parameters

$testSuite is one of the test suite parameters Koha/ks-test-harness.pl receives

=cut

sub _handleTest {
  my ($c, $testSuite) = @_;
  eval {
    my $config = $c->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
    my $inventory_hostname = $c->param('inventory_hostname');

    return unless _checkAllowedInventoryHostname($c, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    my $ansbile_out = `cd $ansible_home && $ansible_playbook_cmd -i production -l $inventory_hostname -e koha_run_${testSuite}_tests=true application_koha.playbook`;
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    my $status = 200;
    if ($ansbile_out_rv) {
      $status = 500;
      $c->render(status => $status, text => $ansbile_out);
      return;
    }

    #Looks in the configured public directories for the test results archive
    $c->reply->static("$inventory_hostname/testResults.tar.gz");
  };
  if ($@) {
    $c->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
}

=head2 _checkAllowedInventoryHostname

Returns 1 if inventory_hostname is allowed to be ran tests on

=cut

sub _checkAllowedInventoryHostname {
  my ($c, $config, $inventory_hostname) = @_;
  unless ($config->{allowed_inventory_hostnames}->{ $inventory_hostname }) {
    $c->render({status => 403, text => "\$inventory_hostname '$inventory_hostname' not in the allowed inventory hostnames list '".@{%{$config->{allowed_inventory_hostnames}}}."'"});
  }
  return 1;
}

1;

