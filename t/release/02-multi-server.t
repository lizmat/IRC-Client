use lib <lib t/release>;
use Test;
use Test::When <release>;
use Test::Notice;
use IRC::Client;
use Test::IRC::Server;

my $Wait = (%*ENV<IRC_CLIENT_TEST_WAIT>//1) * 5;

notice 'Testing connection to four servers and joining two channels in each';

diag 'Starting IRC Servers';
my $s1 = Test::IRC::Server.new: :port<5020>;
my $s2 = Test::IRC::Server.new: :port<5021>;
my $s3 = Test::IRC::Server.new: :port<5022>;
my $s4 = Test::IRC::Server.new: :port<5023>;
END { $s1.kill; $s2.kill; $s3.kill; $s4.kill; };

loop {
    last if $s1.out.elems & $s2.out.elems & $s3.out.elems & $s4.out.elems >= 2;
    sleep 0.5;
}

diag 'Starting IRC Client';
start {
    my $irc = IRC::Client.new(
        :debug(%*ENV<IRC_CLIENT_DEBUG>//0)
        :nick<IRCBot>
        :channels<#perl6 #perl7>
        :servers(
            s1 => { :port<5020>  },
            s2 => { :port<5021>, :nick<OtherBot>, :channels<#perl7 #perl9>  },
            s3 => { :port<5022>, :channels<#perl10 #perl11>  },
            s4 => { :port<5023>, :nick<YetAnotherBot>  },
        )
    ).run;
}

diag 'Waiting for things to happen...';
Promise.in($Wait).then: { $s1.kill; $s2.kill; $s3.kill; $s4.kill; }
await Promise.allof: ($s1, $s2, $s3, $s4).map: *.promise;

dd $s1.out;
diag '----';
dd $s2.out;
diag '----';
dd $s3.out;
diag '----';
dd $s4.out;
diag '----';

#
# my $out = [
#     {:args($[[Any],]), :event("ircd_registered")},
#     {:args($[[5000, 1, "0.0.0.0"],]), :event("ircd_listener_add")},
#     {
#         :args(
#             $[["IRCBot", 1, 'time', "+i", "~Perl6IRC",
#             "simple.poco.server.irc", "simple.poco.server.irc",
#             "Perl6 IRC Client"],]
#         ),
#         :event("ircd_daemon_nick")},
#     {
#         :args($[["IRCBot!~Perl6IRC\@simple.poco.server.irc", "#perl6"],]), :event("ircd_daemon_join")
#     }
# ];
#
# # Fix time signature;
# for $s.out {
#     next unless .<event> eq 'ircd_daemon_nick';
#     .<args>[0][2] = 'time';
# }
#
# is-deeply $s.out, $out, 'Server output looks right';

done-testing;
