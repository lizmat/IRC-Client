use lib <lib t/release>;
use Test;
use Test::When <release>;
use Test::Notice;
use IRC::Client;
use Test::IRC::Server;

my $Wait = (%*ENV<IRC_CLIENT_TEST_WAIT>//1) * 5;

notice 'Testing connection to one server and joining two channels';

diag 'Starting IRC Server';
my $s = Test::IRC::Server.new;
END { $s.kill };

loop {
    last if $s.out.elems >= 2;
    sleep 0.5;
}

diag 'Starting IRC Client';
start {
    my $irc = IRC::Client.new(
        :debug(%*ENV<IRC_CLIENT_DEBUG>//0)
        :nick<IRCBot>
        :channels<#perl6 #perl7>
        :servers(
            meow => { :port<5000>  }
        )
    ).run;
}

diag 'Waiting for things to happen...';
Promise.in($Wait).then: {$s.kill}
await $s.promise;

my $out = [
    {:args($[[Any],]), :event("ircd_registered")},
    {:args($[[5000, 1, "0.0.0.0"],]), :event("ircd_listener_add")},
    {
        :args(
            $[["IRCBot", 1, 'time', "+i", "~Perl6IRC",
            "simple.poco.server.irc", "simple.poco.server.irc",
            "Perl6 IRC Client"],]
        ),
        :event("ircd_daemon_nick")},
    {
        :args($[["IRCBot!~Perl6IRC\@simple.poco.server.irc", "#perl6"],]), :event("ircd_daemon_join")
    },
    {
        :args($[["IRCBot!~Perl6IRC\@simple.poco.server.irc", "#perl7"],]), :event("ircd_daemon_join")
    }
];

# Fix time signature;
for $s.out {
    next unless .<event> eq 'ircd_daemon_nick';
    .<args>[0][2] = 'time';
}

is-deeply $s.out, $out, 'Server output looks right';

done-testing;
