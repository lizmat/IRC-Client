use IRC::Client::Message;
unit role IRC::Client::Message::Numeric does IRC::Client::Message;

has @.args;

method Str { "$.command @.args[]" }
