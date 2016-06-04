use IRC::Client::Message::Privmsg;
unit role IRC::Client::Message::Privmsg::Channel
    does IRC::Client::Message::Privmsg;

has $.channel;
