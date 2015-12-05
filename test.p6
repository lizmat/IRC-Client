use v6;
# use Grammar::Tracer;
grammar IRC::Grammar:ver<1.001001> {
    token TOP        { [ <message> \n ]                                     }
    token message    { [':' <prefix> ' '+ ]? <command> <params>                }
    token prefix     { <servername> | <nick> ['!' <user>]? ['@' <host> ]?  }
    token command    { <letter>+ | <number>**3                                 }
    token params     { ' '* [ ':' <trailing> | <middle> <params> ]?            }
    token middle     { <-[: \0\r\n]> <-[ \0\r\n]>+                             }
    token trailing   { <-[\0\r\n]>+                                            }
    token target     { <to> [ ',' <target> ]?                                  }
    token to         { <channel> | <user> '@' <servername> | <nick> | <mask>   }
    token channel    { ['#' | '&'] <chstring>                                  }
    token servername { <host> }
    token host       { \S+ }# see RFC 952 [DNS:4] for allowed hostnames
    token nick       { <letter> [ <letter> | <number> | <special> ]+           }
    token mask       { <[#$]> <chstring>                                       }
    token chstring   { <-[ \a\0\r\l,]>                                         }
    token user       { <-[ \0\r\l]>+                                           }
    token letter     { <[a..zA..Z]>                                            }
    token number     { <[0..9]>                                                }
    token special    { <[-\[\]\\`^{}]>                                         }
}

class IRC::Grammar::Actions {
    # method class     ($/) { $/.make: ~$/                            }
    # method rules     ($/) { $/.make: ~$/                            }
    # method pair      ($/) { $/.make: $<class>.made => $<rules>.made }
    # method command ($/) { $/.make: $<command> }
    method message   ($/) { $/.make: 42 }
    method TOP       ($/) { $/.make: $<message>».made; } #$<message>».made }
    # }
}

my $res = IRC::Grammar.parse(":verne.freenode.net 372 Perl6IRC :- running for their sustained support.\r\n", :actions(IRC::Grammar::Actions)).made;
say $res;
# say $res<command>;
