unit class IRC::Client::Server;

has         @.channels where .all ~~ Str;
has         @.nick     where .all ~~ Str;
has Int     $.port     where 0 <= $_ <= 65535;
has Str     $.label;
has Str     $.host;
has Str     $.password;
has Str     $.username;
has Str     $.userhost;
has Str     $.userreal;
has Str     $.current-nick     is rw;
has Promise $.promise          is rw;
has Bool    $.is-connected     is rw;
has IO::Socket::Async $.socket is rw;

method Str { $!label }
