use v6;
grammar IRC::Grammar:ver<1.001001> {
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
}

my @messages = (
    ":verne.freenode.net 372 Perl6IRC :- running for their sustained support.\r\n",
    ":Perl6IRC MODE Perl6IRC :+i\r\n",
    ":Perl6IRC!~Perl6IRC@static-67-226-172-41.ptr.terago.net JOIN #perl6bot\r\n",
    ":verne.freenode.net MODE #perl6bot +ns\r\n",
    ":verne.freenode.net 353 Perl6IRC @ #perl6bot :@Perl6IRC\r\n",
    ":ZoffixW!~ZoffixW@unaffiliated/zoffix JOIN #perl6bot\r\n",
    ":ZoffixW!~ZoffixW@unaffiliated/zoffix PRIVMSG #perl6bot :test\r\n",
);
say so IRC::Grammar.parse(@messages[$_]) for 0..@messages.elems-1;
# say IRC::Grammar.parse(":verne.freenode.net 372 Perl6IRC :- running for their sustained support.\r\n");
