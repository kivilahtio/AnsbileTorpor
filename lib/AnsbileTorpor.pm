use 5.22.0;

package AnsbileTorpor;

use Mojo::Base 'Mojolicious';

# ABSTRACT: A poor man's Ansible Tower

=head1 NAME

AnsbileTorpor

=cut

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  my $config;
  if (-e '/etc/ansbiletorpor/AnsbileTorpor.conf') {
    $config = $self->plugin(Config => {file => '/etc/ansbiletorpor/AnsbileTorpor.conf'});
  }
  else {
    $config = $self->plugin(Config => {file => 'config/AnsbileTorpor.conf'});
  }
  checkConfig($self, $config);

  push @{$self->static->paths}, $config->{test_deliverables_dir};

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('default#index');
  $r->get('/koha/build/:inventory_hostname')->to('koha#build');
  $r->get('/koha/test/:inventory_hostname')->to('koha#test');
  $r->get('/koha/gittest/:inventory_hostname')->to('koha#gittest');
}

=head2 checkConfig

Check that configuration options are properly given

=cut

sub checkConfig {
  my ($self, $config) = (@_);

  my $prologue = "Configuration parameter ";
  my @mandatoryConfig = (qw(ansible_home ansible_playbook_cmd test_deliverables_dir));
  foreach my $mc (@mandatoryConfig) {
    die "$prologue '$mc' is not defined" unless ($config->{$mc});
  }

  warn "$prologue 'ansible_home' '$config->{ansible_home}' is not a directory?" unless ( -d $config->{ansible_home} );
  warn "$prologue 'ansible_home' '$config->{ansible_home}' is not readable by the current user '".getlogin()."'?" unless ( -r $config->{ansible_home} );
  warn "$prologue 'test_deliverables_dir' '$config->{test_deliverables_dir}' is not a directory?" unless ( -d $config->{test_deliverables_dir} );
  warn "$prologue 'test_deliverables_dir' '$config->{test_deliverables_dir}' is not readable by the current user '".getlogin()."'?" unless ( -r $config->{test_deliverables_dir} );
}

1;
