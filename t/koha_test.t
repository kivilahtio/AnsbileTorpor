use 5.22.0;

$ENV{MOJO_TESTING} = "1";

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;

my $module = Test::MockModule->new('AnsbileTorpor');
$module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

subtest "Run tests", sub {
  my $testFile = '/tmp/test_koha_ci_1.tar.gz';

  my $t = Test::Mojo->new('AnsbileTorpor');
  $t->get_ok('/koha/test/koha_ci_1')->status_is(200);

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
};

done_testing();

