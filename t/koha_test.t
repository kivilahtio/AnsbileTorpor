use 5.22.0;

$ENV{MOJO_TESTING} = "1";
$ENV{MOJO_MODE} = 'development';
$ENV{MOJO_INACTIVITY_TIMEOUT} = 0; #When debugging it is usefull to not timeout the request
#$ENV{MOJO_LOG_LEVEL} = 'debug';

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;



my $testType = 'all';
subtest "/testall/koha_ci_1", \&testrun;
$testType = 'git';
subtest "/testgit/koha_ci_1", \&testrun;

sub testrun {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $t = Test::Mojo->new('AnsbileTorpor');

  subtest "Trigger Ansible playbook", sub {
    $t->get_ok("/test${testType}/koha_ci_1")
      ->status_is(200)
      ->content_like(qr/Ansible/i, 'Ansible mentioned')
      ->content_like(qr/koha_ci_1/i, '--limit koha_ci_1 passed to Ansible playbook')
      ->content_like(qr/koha_run_${testType}_tests=true/i, "-e koha_run_${testType}_tests passed to Ansible playbook");

    #print $t->tx->res->body();
  };

  subtest "Fetch testResults.tar.gz", sub {
    my $testResultsTestFile = $t->app->config->{ansible_home}.'/koha_ci_1/testResults.tar.gz';
    my $testResultsDistributedPath = $t->app->config->{test_deliverables_dir}.'/koha_ci_1/testResults.tar.gz';

    my $error = `tar --test-label -f $testResultsTestFile`;
    ok(not($error), "Test results file, before downloading actually is a .tar-package");
    is(${^CHILD_ERROR_NATIVE}, 0, "And no error code returned from the shell");

    ok(-e($testResultsDistributedPath), 'Simulating: Test results file is written to disk by Ansible');

    $t->get_ok("/koha_ci_1/testResults.tar.gz")
  };
}


done_testing();

