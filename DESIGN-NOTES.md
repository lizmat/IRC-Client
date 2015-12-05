## Just some notes jotted down while reading RFCs

#### RFC 1459

http://irchelp.org/irchelp/rfc/rfc.html

Nicks can only be 9-chars long max.

Channels names are strings (beginning with a ‘&’ or ‘#’ character) of length up
to 200 characters. Apart from the the requirement that the first character being
either ‘&’ or ‘#’; the only restriction on a channel name is that it may not
contain any spaces (’ ‘), a control G (^G or ASCII 7), or a comma (‘,’ which is
used as a list item separator by the protocol).

A channel operator is identified by the ‘@’ symbol next to their nickname
whenever it is associated with a channe

Because of IRC’s scandanavian origin, the characters {}| are considered to be
the lower case equivalents of the characters []\, respectively. This is a
critical issue when determining the equivalence of two nicknames.

Each IRC message may consist of up to three main parts: the prefix (optional),
the command, and the command parameters (of which there may be up to 15). The
prefix, command, and all parameters are separated by one (or more) ASCII space
character(s) (0x20).

***Clients should not use prefix when sending a message from themselves;***

The command must either be a valid IRC command or a three (3) digit number represented in ASCII text.

IRC messages are always lines of characters terminated with a CR-LF (Carriage Return - Line Feed) pair, and these messages shall ***not exceed 512 characters*** in length, counting all characters **including the trailing CR-LF**. Thus, there are 510 characters maximum allowed for the command and its parameters. There is no provision for continuation message lines. See section 7 for more details about current implementations.


The BNF representation for this is:

::=

[':' <prefix> <SPACE> ] <command> <params> <crlf>

::=

<servername> | <nick> [ '!' <user> ] [ '@' <host> ]

::=

<letter> { <letter> } | <number> <number> <number>

::=

' ' { ' ' }

::=

<SPACE> [ ':' <trailing> | <middle> <params> ]

::=

<Any *non-empty* sequence of octets not including SPACE or NUL or CR or LF, the first of which may not be ':'>

::=

<Any, possibly *empty*, sequence of octets not including NUL or CR or LF>

::=

CR LF
