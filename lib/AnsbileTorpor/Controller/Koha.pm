use 5.22.0;

package AnsbileTorpor::Controller::Koha;

use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

AnsbileTorpor::Controller::Koha

=cut

=head2 build

Runs the Ansible-playbooks relevant to the given inventory_hostname.
Building, reconfiguring and upgrading changes or even rebuilding the complete infrastructure if need be.

=cut

sub build {
  my $self = shift;
  my $config = $self->config();
  my $ansible_home = $config->{ansible_home};
  my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
  my $lxc_host = $config->{lxc_host};
  my $allowed_inventory_hostnames = $config->{allowed_inventory_hostnames};

  my $inventory_hostname = $self->param('inventory_hostname');
  unless ($allowed_inventory_hostnames->{ $inventory_hostname }) {
    $self->render({status => 403, text => "\$inventory_hostname '$inventory_hostname' not in the allowed inventory hostnames list '".@{%$allowed_inventory_hostnames}."'"});
  }

  #Ansible scripts will propably take some time
  my $ansbile_out = `cd $ansible_home && $ansible_playbook_cmd -i production -l $inventory_hostname -l $lxc_host everything.playbook`;
  my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

  my $status = 200;
  $status = 500 if $ansbile_out_rv;
  $self->render(status => $status, text => $ansbile_out);
}

=head2 test

Runs the Koha's test suite and gathers other code quality metrics.
Tar's them up and sends them with the response.

=cut

sub test {
  my $self = shift;
  my $config = $self->config();
  my $ansible_home = $config->{ansible_home};
  my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};
  my $allowed_inventory_hostnames = $config->{allowed_inventory_hostnames};

  my $inventory_hostname = $self->param('inventory_hostname');
  unless ($allowed_inventory_hostnames->{ $inventory_hostname }) {
    $self->render({status => 403, text => "\$inventory_hostname '$inventory_hostname' not in the allowed inventory hostnames list '".@{%$allowed_inventory_hostnames}."'"});
  }

  #Ansible scripts will propably take some time
  my $ansbile_out = `cd $ansible_home && $ansible_playbook_cmd -i production -l $inventory_hostname koha_runtests.playbook`;
  my $ansbile_out_rv = ${^CHILD_ERROR_NATIVE};

  my $status = 200;
  if ($ansbile_out_rv) {
    $status = 500 if $ansbile_out_rv;
    $self->render(status => $status, text => $ansbile_out) if $status !~ /^2/;
    return;
  }

  #Looks in the configured public directories for the test results archive
  $self->reply->static("$inventory_hostname/testResults.tar.gz");
}

1;

