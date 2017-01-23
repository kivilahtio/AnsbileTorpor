use 5.22.0;

package AnsbileTorpor;
use Mojo::Base 'Mojolicious';

# ABSTRACT: A poor man's Ansible Tower

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');
  my $config = $self->plugin(Config => {file => 'config/AnsbileTorpor.conf'});
  checkConfig($self, $config);

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('default#index');
  $r->get('/koha/build/:inventory_hostname')->to('koha#build');
  $r->get('/koha/test/:inventory_hostname')->to('koha#test');
}

=head2 checkConfig

Check that configuration options are properly given

=cut

sub checkConfig {
  my ($self, $config) = (@_);

  my $prologue = "Configuration parameter ";
  my @mandatoryConfig = (qw(ansible_home ansible_playbook_cmd));
  foreach my $mc (@mandatoryConfig) {
    die "$prologue '$mc' is not defined" unless ($config->{$mc});
  }

  warn "$prologue 'ansible_home' '$config->{ansible_home}' is not a directory?" unless ( -d $config->{ansible_home} );
  warn "$prologue 'ansible_home' '$config->{ansible_home}' is not owned by current user '".getlogin()."'?" unless ( -o $config->{ansible_home} );
}

1;
