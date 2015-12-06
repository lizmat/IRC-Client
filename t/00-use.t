#!perl6

use lib 'lib';
use Test;

use-ok 'IRC::Client';
use-ok 'IRC::Grammar';
use-ok 'IRC::Grammar::Actions';
use-ok 'IRC::Parser';
use-ok 'IRC::Client::Plugin::Debugger';
use-ok 'IRC::Client::Plugin::PingPong';

done-testing;
