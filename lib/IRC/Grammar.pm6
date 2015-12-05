# use Grammar::Debugger;
unit grammar IRC::Grammar:ver<1.001001>;
token TOP { <message> }
token SPACE { ' '+ }
token message { [':' <prefix> <SPACE> ]? <command> <params> \n }
    token prefix  {
        [ <servername> || <nick> ['!' <user>]? ['@' <host>]? ]
        <before <SPACE>>
    }
        token servername { <host> }
        token nick { <letter> [ <letter> | <number> | <special> ]* }
        token user { <-[\ \0\r\n]>+?  <before [<SPACE> | '@']>}
        token host { <-[\s!@]>+ }
    token command { <letter>+ | <number>**3 }
    token params { <SPACE>* [ ':' <trailing> | <middle> <params> ]? }
        token middle { <-[:\ \0\r\n]> <-[\ \0\r\n]>* }
        token trailing { <-[\0\r\n]>* }

    token letter { <[a..zA..Z]> }
    token number { <[0..9]> }
    token special { <[-\[\]\\`^{}]> }

# unit class IRC::Grammar::Actions:ver<1.001001>;
# method TOP      ($/) { $/.make: $<message>».made }
# method message  ($/) { $/.make:
#     prefix  => $<prefix> .made,
#     command => $<command>.made,
#     params  => $<params  .made,
# }
# method prefix   ($/) { [<servername> | <nick>] [ '!' <user> ]? [ '@' <host> ]? }
# method command  ($/) { <letter>+ | <number>**3                                 }
# method params   ($/) { ' '+ [ ':' <trailing> | <middle> <params> ]?            }
# method middle   ($/) { <-[: \0\r\n]> <-[ \0\r\n]>+                             }
# method trailing ($/) { <-[\0\r\n]>                                             }
#
# method class     ($/) { $/.make: ~$/                            }
# method rules     ($/) { $/.make: ~$/                            }
# method pair      ($/) { $/.make: $<class>.made => $<rules>.made }
# method TOP       ($/) { $/.make: $<pair>».made                  }
