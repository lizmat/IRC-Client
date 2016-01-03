use v6;
use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin::Debugger;

class IRC::Client::Plugin::AddressedPlugin is IRC::Client::Plugin {
    method irc-addressed ($irc, $e, $where) {
        $irc.privmsg: $where[0], "$where[1], you addressed me";
    }
}

my $irc = IRC::Client.new(
    :host<localhost>
    :channels<#perl6bot #zofbot>
    :debug
    :plugins(
        IRC::Client::Plugin::Debugger.new,
        IRC::Client::Plugin::AddressedPlugin.new
    )
).run;