unit grammar IRC::Client::Grammar;
token TOP { <message>+ <leftovers> }
token leftovers { \N* }
token SPACE { ' '+ }
token message { [':' <prefix> <SPACE> ]? <command> <params> \n }
    token prefix  {
        [ <servername> || <nick> ['!' <user>]? ['@' <host>]? ]
        <before <SPACE>>
    }
        token servername { <host> }
        token nick { <letter> [ <letter> | <number> | <special> ]* }
        token user { <-[\ \x[0]\r\n]>+?  <before [<SPACE> | '@']>}
        token host { <-[\s!@]>+ }
    token command { <letter>+ | <number>**3 }
    token params { <SPACE>* [ ':' <trailing> | <middle> <params> ]? }
        token middle { <-[:\ \x[0]\r\n]> <-[\ \x[0]\r\n]>* }
        token trailing { <-[\x[0]\r\n]>* }

    token letter { <[a..zA..Z]> }
    token number { <[0..9]> }
    token special { <[-_\[\]\\`^{}]> }
