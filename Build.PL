use 5.22.0;
use Module::Build;


my $class = Module::Build->subclass(
  class => "Module::Build::Custom",
  code => <<'SUBCLASS' );

sub ACTION_install {
  my $self = shift;
  $self->SUPER::ACTION_install;

  my $sname = 'AnsbileTorpor';
  my $ssrc  = 'etc/systemd/system/ansbiletorpor.service';
  my $sdst  = '/etc/systemd/system/ansbiletorpor.service';
  my $uname = 'ansible';
  my $cdir  = '/etc/ansbiletorpor';
  ###Add the ansible-user###
  my $userExists = `/bin/grep -P '$uname' /etc/passwd`;
  unless ($userExists) {
    $self->log_info( "Adding user '$uname'\n" );
    $self->do_system( '/usr/sbin/useradd '.$uname ) unless $userExists;
  }
  else {
    $self->log_info( "User '$uname' exists\n" );
  }

  ###Install systemd service and system config file
  require File::Copy;
  $self->log_info( "Deploying the '$sname'-service\n" );
  File::Copy::copy($ssrc, $sdst);
  unless (-d $cdir) {
    $self->log_info( "Creating '$cdir'\n" );
    mkdir $cdir;
  }
  unless (-e "$cdir/$sname.conf") {
    $self->log_info( "Creating '$cdir/$sname.conf'\n" );
    File::Copy::copy("config/$sname.conf", "$cdir/$sname.conf");
  }
  else {
    $self->log_info( "'$cdir/$sname.conf' exists\n" );
  }
#  unless (-e '/etc/hetula/log4perl.conf') {
#    $self->log_info( "Creating '/etc/hetula/log4perl.conf'\n" );
#    File::Copy::copy('config/log4perl.conf', '/etc/hetula/log4perl.conf');
#  }
#  else {
#    $self->log_info( "'/etc/hetula/log4perl.conf' exists\n" );
#  }
  $self->log_info( "Enabling '$sname'-service\n" );
  $self->do_system( '/bin/systemctl daemon-reload' );
  $self->do_system( '/bin/systemctl enable '.lc($sname) );
}

sub ACTION_test {
  my $self = shift;

  $self->do_system( '/usr/bin/prove -Ilib t' );
}

sub ACTION_commit {
  #This is just a useless reminder to extend more features
  my $self = shift;

  $self->depends_on("test");
  $self->log_warn( "#I am a useless commit action stub#" );
}
SUBCLASS

$class->new(
  module_name => 'AnsbileTorpor',
  dist_author => 'Olli-Antti Kivilahti <olli-antti.kivilahti@jns.fi>',
  dist_abstract => "A poor man's Ansible Tower",

  build_requires => {

  },
  requires => {
    'Mojolicious'                               => '> 0.01',
    'Test::MockModule'                          => '> 0.01',
    'IPC::Cmd'                                  => '> 0.01',
  },
)->create_build_script;


