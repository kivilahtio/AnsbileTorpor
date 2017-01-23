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
  checkConfig($config);

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to(controller => 'AnsbileTorpor::Controller::Default', action => 'index');
  $r->get('/koha/build/:inventory_hostname')->to(controller => 'AnsbileTorpor::Controller::Koha', action => 'build');
  $r->get('/koha/test/:inventory_hostname')->to(controller => 'AnsbileTorpor::Controller::Koha', action => 'test');
}

=head2 checkConfig

Check that configuration options are properly given

=cut

sub checkConfig {
  my ($config) = (@_);

  my $prologue = "Configuration parameter ";
  my @mandatoryConfig = (qw(ansible_home));
  foreach my $mc (@mandatoryConfig) {
    die "$prologue '$mc' is not defined" unless ($config->{$mc});
  }

  die "$prologue 'ansible_home' '$config->{ansible_home}' is not a directory?" unless ( -d $config->{ansible_home} );
  die "$prologue 'ansible_home' '$config->{ansible_home}' is not owned by current user '".getlogin()."'?" unless ( -o $config->{ansible_home} );
}

1;
