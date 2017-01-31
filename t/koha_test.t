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

  #print $t->tx->res->body;
};


subtest "/koha/alltest/koha_ci_1", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $testFile = '/tmp/test_koha_ci_1.tar.gz';

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/alltest/koha_ci_1')->status_is(200);

  my $body = $t->tx->res->body;
  ok($body, 'Given the response body');

  open(my $FH, '>:raw', $testFile);
  print $FH $body;
  close($FH);
  ok(-e($testFile), 'And the file is written to disk');

  my $error = `tar --test-label -f $testFile`;
  ok(not($error), "Then the file is validated as a .tar-package");
  is(${^CHILD_ERROR_NATIVE}, 0, "And no error code returned from the shell");

  unlink($testFile);
  ok(not(-e($testFile)), 'Finally the file is cleaned from the disk');

  #print $body;
};


subtest "/koha/gittest/koha_ci_1", sub {
  my $module = Test::MockModule->new('AnsbileTorpor');
  $module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

  my $testFile = '/tmp/test_koha_ci_1.tar.gz';

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/gittest/koha_ci_1')->status_is(200);

  my $body = $t->tx->res->body;
  ok($body, 'Given the response body');

  open(my $FH, '>:raw', $testFile);
  print $FH $body;
  close($FH);
  ok(-e($testFile), 'And the file is written to disk');

  my $error = `tar --test-label -f $testFile`;
  ok(not($error), "Then the file is validated as a .tar-package");
  is(${^CHILD_ERROR_NATIVE}, 0, "And no error code returned from the shell");

  unlink($testFile);
  ok(not(-e($testFile)), 'Finally the file is cleaned from the disk');

  #print $body;
};

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

