use lib <lib>;
use IRC::Client;

.run with IRC::Client.new:
    :nick<MahBot>
    :host(%*ENV<IRC_CLIENT_HOST> // 'irc.freenode.net')
    :channels<#zofbot>
    :2debug
    :plugins(class :: does IRC::Client::Plugin {
        my class NameLookup { has $.channel; has @.users; has $.e; }
        has %.lookups of NameLookup;

        method irc-to-me ($e where /^ 'users in ' $<channel>=\S+/) {
            my $channel = ~$<channel>;
            return 'Look up of this channel is already in progress'
                if %!lookups{$channel};

            %!lookups{$channel} = NameLookup.new: :$channel :$e;
            $.irc.send-cmd: 'NAMES', $channel;
            Nil;
        }
        method irc-n353 ($e where so %!lookups{ $e.args[2] }) {
            %!lookups{ $e.args[2] }.users.append: $e.args[3].words;
            Nil;
        }
        method irc-n366 ($e where so %!lookups{ $e.args[1] }) {
            my $lookup = %!lookups{ $e.args[1] }:delete;
            $lookup.e.reply: "Users in $lookup.channel(): $lookup.users()[]";
            Nil;
        }

    }.new)
