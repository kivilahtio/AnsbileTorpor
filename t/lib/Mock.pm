use 5.22.0;

package t::lib::Mock;

sub AnsbileTorpor_checkConfig {
  my ($app, $config) = @_;

  $config = $app->config();
  $config->{ansible_home} = 't/ansible_home';
  $config->{ansible_playbook_cmd} = './ansible_playbook';
  $config->{test_deliverables_dir} = 't/ansible_home';
}

sub AnsbileTorpor_checkConfigFaulty {
  my ($app, $config) = @_;

  $config = $app->config();
  $config->{ansible_home} = 't/ansible_home';
  $config->{ansible_playbook_cmd} = './ansbille_plybk';
  $config->{test_deliverables_dir} = 't/ansible_home';
}

1;

