use 5.22.0;

$ENV{MOJO_TESTING} = "1";

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;



subtest "/koha/build/koha_production is not an allowed inventory_hostname", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/build/koha_production')
    ->status_is(403)
    ->content_like(qr/koha_production/i, 'Unauthorized inventory_hostname mentioned')
    ->content_like(qr/not in the allowed inventory/i, 'Description of the error received');

  #print $t->tx->res->body();
};


subtest "/koha/build/koha_ci_1", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/build/koha_ci_1')
    ->status_is(200)
    ->content_like(qr/Ansible/i, 'Ansible mentioned')
    ->content_like(qr/koha_ci_1/i, '--limit koha_ci_1 passed to Ansible playbook')
    ->content_like(qr/koha_ci_1/i, '--limit hephaestus passed to Ansible playbook');

  #print $t->tx->res->body();
};


subtest "/koha/build/koha_ci_1 is misconfigured", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfigFaulty);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/build/koha_ci_1')
    ->status_is(500)
    ->content_like(qr!sh: 1: ./ansbille_plybk: not found!, 'Mangled ansible-playbook command not found');

  #print "BODY\n".$t->tx->res->body()."\n";
};



done_testing();

