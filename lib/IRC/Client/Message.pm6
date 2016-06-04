unit package IRC::Client::Message;

role IRC::Client::Message {
    has       $.irc      is required;
    has Str:D $.nick     is required;
    has Str:D $.username is required;
    has Str:D $.host     is required;
    has Str:D $.usermask is required;
    has Str:D $.command  is required;
    has Str:D $.server   is required;
    has       @.args     is required;

    method Str { "$.command @.args[]" }
}

constant M = IRC::Client::Message;

role Join             does M       { has $.channel;                          }
role Notice           does M       { has $.text;                             }
role Notice::Channel  does Notice  { has $.channel;                          }
role Notice::Me       does Notice  {                                         }
role Mode             does M       { has @.modes;                            }
role Mode::Channel    does Mode    { has $.channel;                          }
role Mode::Me         does Mode    {                                         }
role Numeric          does M       {                                         }
role Privmsg          does M       { has $.text;                             }
role Privmsg::Channel does Privmsg { has $.channel;                          }
role Privmsg::Me      does Privmsg {                                         }
role Unknown          does M       { method Str { "❚⚠❚ $.command @.args[]" } }

role Ping does M {
    method reply { $.irc.send-cmd: 'PONG', @.args; }
}
