use 5.22.0;

use Modern::Perl;
use English;

package AnsbileTorpor;

use Mojo::Base 'Mojolicious';

# ABSTRACT: A poor man's Ansible Tower

=head1 NAME

AnsbileTorpor

=cut

use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use IPC::Cmd;

=head2 startup

This method will run once at server start

=cut

sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  my $log = Mojo::Log->new(
                           level => 'debug',
#                           path  => '/tmp/mojo.log',
                          );
  $self->log($log);

  my $config;
  if (not($ENV{MOJO_TESTING}) && -e '/etc/ansbiletorpor/AnsbileTorpor.conf') {
    $config = $self->plugin(Config => {file => '/etc/ansbiletorpor/AnsbileTorpor.conf'});
  }
  else {
    $config = $self->plugin(Config => {file => 'config/AnsbileTorpor.conf'});
  }
  $self->checkConfig($config);

  if (not(getpwuid($<) eq 'ansible') && not($ENV{MOJO_TESTING})) {
    die "AnsbileTorpor must be ran as the 'ansible'-user!";
  }

#  push @{$self->static->paths}, $config->{test_deliverables_dir}; #This didn't work.
  $self->static->paths->[1] = $config->{test_deliverables_dir};

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/:req_action/:inventory_hostname')->to('deploy#any');
  $r->get('/')->to('default#index');
}

=head2 checkConfig

Check that configuration options are properly given

=cut

sub checkConfig {
  my ($self, $config) = @_;
  $self->log->info("Checking config and validating Ansible playbook commands. This might take a minute or so.");
  _preCheckConfigHook($self, $config);


  my $prologue = "Configuration parameter ";
  my @mandatoryConfig = (qw(ansible_home ansible_playbook_cmd test_deliverables_dir allowedActionsMap));
  foreach my $mc (@mandatoryConfig) {
    die "$prologue '$mc' is not defined" unless ($config->{$mc});
  }

  die "$prologue 'ansible_home' '$config->{ansible_home}' is not a directory?" unless ( -d $config->{ansible_home} );
  die "$prologue 'ansible_home' '$config->{ansible_home}' is not readable by the current user '".getlogin()."'?" unless ( -r $config->{ansible_home} );
  die "$prologue 'test_deliverables_dir' '$config->{test_deliverables_dir}' is not a directory?" unless ( -d $config->{test_deliverables_dir} );
  die "$prologue 'test_deliverables_dir' '$config->{test_deliverables_dir}' is not readable by the current user '".getlogin()."'?" unless ( -r $config->{test_deliverables_dir} );

  ##Validate allowedActionsMap, that it is properly defined and the commands actually compile.
  die "$prologue 'allowedActionsMap' '$config->{allowedActionsMap}' is not a HASH" unless(ref($config->{allowedActionsMap}) eq 'HASH');
  my $conf = $config->{allowedActionsMap};
  my @k = keys(%$conf);
  die "$prologue 'allowedActionsMap' '$config->{allowedActionsMap}' is missing action definitions?" unless(@k);

  my $errors = 0;
  foreach my $k (@k) { #Validate actions
    unless (ref($conf->{$k}) eq 'HASH') {
      $self->log->warn("$prologue 'allowedActionsMap' action '$k' is not a HASH");
      $errors++;
      next;
    }

    my @h = keys(%{$conf->{$k}});
    unless (@h) {
      $self->log->warn("$prologue 'allowedActionsMap' '$config->{allowedActionsMap}' is missing host definitions?");
      $errors++;
      next;
    }
    foreach my $h (@h) { #Validate host commands
      my ($exitValue, $errorMessage, $fullBuf, $stdoutBuf, $stderrBuf, $cmd) = $self->dispatchAnsiblePlaybook($conf->{$k}->{$h}, '--syntax-check');
      unless ($exitValue == 0) {
        $self->log->warn("$prologue 'allowedActionsMap' action '$k' command '''$conf->{$k}->{$h}''' doesn't pass --syntax-check!\nexit value: $exitValue\nerror message: $errorMessage\nfull output: ".(ref($fullBuf) eq 'ARRAY' ? join("\n",@$fullBuf) : $fullBuf)."\n");
        $errors++;
        next;
      }
    }
  }
  die "Dying because of '$errors' errors" if $errors;
}

=head2 _preCheckConfigHook

Allow hooking in from Test::MockModule and injecting test context

=cut

sub _preCheckConfigHook {
  my ($self, $config) = @_;
  return "Overload me";
}

=head2 dispatchAnsiblePlaybook

Executes a ansible-playbook command

@PARAM1 AnsbileTorpor or Ansbile::Torpor::Controller
@PARAM2 String, the ansible playbook command parameters without the ansible-playbook -prefix
@PARAM3 List, any extra playbook parameters concatenated after the ansible-playbook command

@RETURNS List of:
    Integer, exit value of the ansible playbook
    String, error message, this is generally a pretty printed value of $? or $@
    ArrayRef of Strings, This is an array reference containing all the output the command generated
    ArrayRef of Strings, This is an array reference containing all the output sent to STDOUT the command generated
    ArrayRef of Strings, This is an arrayreference containing all the output sent to STDERR the command generated
    String, the full command used

=cut

sub dispatchAnsiblePlaybook {
  my ($self, $playbookParams, @extraParms) = @_;
  my $config = $self->config();
  my $ansible_home = $config->{ansible_home};
  my $ansible_playbook_cmd = $config->{ansible_playbook_cmd};

  #Ansible scripts will propably take some time
  my $cmd = "cd $ansible_home && $ansible_playbook_cmd $playbookParams @extraParms";

  my ( $success, $errorMessage, $fullBuf, $stdoutBuf, $stderrBuf ) =
          IPC::Cmd::run( command => $cmd, verbose => 0 );
  my $exitValue = ${^CHILD_ERROR_NATIVE} >> 8;
  my $killSignal = ${^CHILD_ERROR_NATIVE} & 127;
  my $coreDumpTriggered = ${^CHILD_ERROR_NATIVE} & 128;

  return ($exitValue, $errorMessage, $fullBuf, $stdoutBuf, $stderrBuf, $cmd);
}

=head2 getDispatchRules

@RETURNS String, ansible-playbook parameters for the given action and inventory_hostname

@THROWS die, if the given action or inventory_hostname is not allowed.

=cut

sub getDispatchRules {
  my ($self, $action, $inventory_hostname) = @_;
  my $allowedAction = $self->config->{allowedActionsMap}->{$action};
  die "Forbidden action '$action'. See 'allowedActionsMap' for allowed actions" unless $allowedAction;
  my $allowedHostCmd = $allowedAction->{$inventory_hostname};
  die "Forbidden inventory_hostname '$inventory_hostname' for action '$action'. See 'allowedActionsMap->{$action}' for allowed inventory_hostnames" unless $allowedHostCmd;
  return $allowedHostCmd;
}

1;
