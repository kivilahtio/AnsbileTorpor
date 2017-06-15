use 5.22.0;

$ENV{MOJO_TESTING} = "1";

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;



subtest "/koha/alltest/koha_production is not an allowed inventory_hostname", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/alltest/koha_production')
    ->status_is(403)
    ->content_like(qr/koha_production/i, 'Unauthorized inventory_hostname mentioned')
    ->content_like(qr/not in the allowed inventory/i, 'Description of the error received');

  print $t->tx->res->body;
};

my $testType = 'all';
subtest "/koha/alltest/koha_ci_1", \&testrun;
$testType = 'git';
subtest "/koha/gittest/koha_ci_1", \&testrun;

sub testrun {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok("/koha/${testType}test/koha_ci_1")
    ->status_is(200)
    ->content_like(qr/Ansible/i, 'Ansible mentioned')
    ->content_like(qr/koha_ci_1/i, '--limit koha_ci_1 passed to Ansible playbook')
    ->content_like(qr/koha_run_${testType}_tests=true/i, '-e koha_run_${testType}_tests passed to Ansible playbook');

  #print $t->tx->res->body();

  my $testResultsFile = $t->app->config->{ansible_home}.'/koha_ci_1/testResults.tar.gz';

  ok(-e($testResultsFile), 'Test results file is written to disk by Ansible');

  my $error = `tar --test-label -f $testResultsFile`;
  ok(not($error), "Then the file is validated as a .tar-package");
  is(${^CHILD_ERROR_NATIVE}, 0, "And no error code returned from the shell");
}

subtest "/koha/test/koha_ci_1 is misconfigured", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfigFaulty);

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/alltest/koha_ci_1')
    ->status_is(500)
    ->content_like(qr!sh: 1: ./ansbille_plybk: not found!, 'Mangled ansible-playbook command not found');

  #print "BODY\n".$t->tx->res->body()."\n";
};


done_testing();

