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
