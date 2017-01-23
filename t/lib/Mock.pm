use 5.22.0;

package t::lib::Mock;

sub AnsbileTorpor_checkConfig {
  my ($app, $config) = @_;

  $config = $app->config();
  $config->{ansible_home} = 't/ansible_home';
  $config->{ansible_playbook_cmd} = './ansible_playbook';
}

1;

