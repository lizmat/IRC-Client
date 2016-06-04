unit role IRC::Client::Message;

has       $.irc      is required;
has Str:D $.nick     is required;
has Str:D $.username is required;
has Str:D $.host     is required;
has Str:D $.usermask is required;
has Str:D $.command  is required;
has Str:D $.server   is required;
