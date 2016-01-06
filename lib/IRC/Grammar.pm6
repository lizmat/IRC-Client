unit grammar IRC::Grammar:ver<2.003001>;
token TOP { <message>+ }
token SPACE { ' '+ }
token message { [':' <prefix> <SPACE> ]? <command> <params> \n }
    token prefix  {
        [ <servername> || <nick> ['!' <user>]? ['@' <host>]? ]
        <before <SPACE>>
    }
        token servername { <host> }
        token nick { <letter> [ <letter> | <number> | <special> ]* }
        token user { <-[\ \x0\r\n]>+?  <before [<SPACE> | '@']>}
        token host { <-[\s!@]>+ }
    token command { <letter>+ | <number>**3 }
    token params { <SPACE>* [ ':' <trailing> | <middle> <params> ]? }
        token middle { <-[:\ \x0\r\n]> <-[\ \x0\r\n]>* }
        token trailing { <-[\x0\r\n]>* }

    token letter { <[a..zA..Z]> }
    token number { <[0..9]> }
    token special { <[-_\[\]\\`^{}]> }
