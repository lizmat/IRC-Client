# use Grammar::Debugger;
unit grammar IRC::Grammar:ver<1.001001>;
token ws { ' ' }
token TOP        { [ <message> \r\n ]*                                     }
token message    { [':' <prefix> ' '+ ]? <command> <params>                }
token prefix     { [<servername> | <nick>] [ '!' <user> ]? [ '@' <host> ]? }
token command    { <letter>+ | <number>**3                                 }
token params     { ' '+ [ ':' <trailing> | <middle> <params> ]?            }
token middle     { <-[: \0\r\n]> <-[ \0\r\n]>+                             }
token trailing   { <-[\0\r\n]>+                                            }
token target     { <to> [ ',' <target> ]?                                  }
token to         { <channel> | <user> '@' <servername> | <nick> | <mask>   }
token channel    { ['#' | '&'] <chstring>                                  }
token servername { \S+ } # see RFC 952 [DNS:4] for details on allowed hostnames
token nick       { <letter> [ <letter> | <number> | <special> ]+           }
token mask       { <[#$]> <chstring>                                       }
token chstring   { <-[ \a\0\r\l,]>                                         }
token user       { <-[ \0\r\l]>+                                           }
token letter     { <[a..zA..Z]>                                            }
token number     { <[0..9]>                                                }
token special    { <[-\[\]\\`^{}]>                                         }

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
