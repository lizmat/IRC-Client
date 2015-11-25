use v6;
use IRC::Client;
unit role IRC::Client::Plugin:ver<1.001001>;

multi method inverval (           ) {    0    }
multi method inverval (IRC::Client) {   ...   }
multi method msg      (           ) {  False  }
multi method msg      (IRC::Client) {   ...   }
