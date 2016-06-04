use IRC::Client::Message;
unit role IRC::Client::Message::Unknown does IRC::Client::Message;

method Str { "❚⚠❚ $.command @.args[]" }
