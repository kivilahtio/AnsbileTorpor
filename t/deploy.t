use 5.22.0;

$ENV{MOJO_TESTING} = "1";

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;



subtest "/deploy/hetula_production is not an allowed inventory_hostname", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('_preCheckConfigHook', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/deploy/hetula_production')
    ->status_is(403)
    ->content_like(qr/hetula_production/i, 'Unauthorized inventory_hostname mentioned')
    ->content_like(qr/not in the allowed inventory/i, 'Description of the error received');

  #print $t->tx->res->body();
};


subtest "/deploy/hetula_ci", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('_preCheckConfigHook', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/deploy/hetula_ci')
    ->status_is(200)
    ->content_like(qr/Ansible/i, 'Ansible mentioned')
    ->content_like(qr/hetula_ci/i, '--limit hetula_ci passed to Ansible playbook')
    ->content_like(qr/hephaestus/i, '--limit hephaestus passed to Ansible playbook');

  #print $t->tx->res->body();
};


subtest "/deploy/hetula*", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('_preCheckConfigHook', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/deploy/hetula*')
    ->status_is(200)
    ->content_like(qr/Ansible/i, 'Ansible mentioned')
    ->content_like(qr/hetula*/i, '--limit hetula* passed to Ansible playbook')
    ->content_like(qr/hephaestus/i, '--limit hephaestus passed to Ansible playbook');

  #print $t->tx->res->body();
};


subtest "/deploy/hetula_ci is misconfigured", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('_preCheckConfigHook', \&t::lib::Mock::AnsbileTorpor_checkConfigFaulty);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/deploy/hetula_ci')
    ->status_is(500)
    ->content_like(qr!sh: 1: ./ansbille_plybk: not found!, 'Mangled ansible-playbook command not found');

  #print $t->tx->res->body();
};



done_testing();

