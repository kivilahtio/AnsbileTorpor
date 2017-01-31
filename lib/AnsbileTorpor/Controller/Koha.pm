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
  my $status = 200;
  my $output;
  eval {
    my $config = $self->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
    my $lxc_host = $config->{lxc_host};
    my $inventory_hostname = $self->param('inventory_hostname');

    _checkAllowedInventoryHostname($self, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    $output = `cd $ansible_home && $ansible_playbook_cmd -i production -l "$inventory_hostname $lxc_host" everything.playbook 2>&1`;
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    $status = 500 if $ansbile_out_rv;
  };
  if ($@) {
    return $self->render(status => 403, text => $@) if $@ =~ /not in the allowed inventory/;
    return $self->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
  else {
    return $self->render(status => $status, text => $output);
  }
}

=head2 alltest

Runs the Koha's big test suite and gathers other code quality metrics.
Tar's them up and sends them with the response.

=cut

sub alltest {
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
  my $status = 200;
  my $output;
  my $inventory_hostname = $c->param('inventory_hostname');
  eval {
    my $config = $c->config();
    my $ansible_home = $config->{ansible_home};
    my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};

    _checkAllowedInventoryHostname($c, $config, $inventory_hostname);

    #Ansible scripts will propably take some time
    $output = `cd $ansible_home && $ansible_playbook_cmd -i production -l $inventory_hostname -e koha_run_${testSuite}_tests=true application_koha.playbook 2>&1`;
    my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

    if ($ansbile_out_rv) {
      die $output;
    }
  };
  if ($@) {
    return $c->render(status => 403, text => $@) if $@ =~ /not in the allowed inventory/;
    return $c->render(status => 500, text => $@); #Hopefully with a good stack trace
  }
  else {
    #Looks in the configured public directories for the test results archive
    return $c->reply->static("$inventory_hostname/testResults.tar.gz");
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

