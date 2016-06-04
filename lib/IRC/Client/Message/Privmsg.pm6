use IRC::Client::Message;
unit role IRC::Client::Message::Privmsg does IRC::Client::Message;

has $.what;
