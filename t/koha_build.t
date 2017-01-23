use 5.22.0;

$ENV{MOJO_TESTING} = "1";

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Test::MockModule;

use t::lib::Mock;

my $module = Test::MockModule->new('AnsbileTorpor');
$module->mock('checkConfig', \&t::lib::Mock::AnsbileTorpor_checkConfig);

my $t = Test::Mojo->new('AnsbileTorpor');
$t->get_ok('/koha/build/koha_ci_1')->status_is(200) 
                                  ->content_like(qr/Ansible/i)
                                  ->content_like(qr/koha_ci_1/i);
done_testing();

