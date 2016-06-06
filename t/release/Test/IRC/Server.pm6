unit class Test::IRC::Server;

use JSON::Fast;

has $!port;
has $!proc;
has Promise $.promise;
has @.out;

submethod BUILD (:$!port = 5000, :$server = 't/release/servers/01-basic.pl') {
    $!proc = Proc::Async.new: 'perl', $server, $!port;
    $!proc.stdout.tap: {
        %*ENV<IRC_CLIENT_DEBUG> and dd .lines;
        @!out.append: |.lines».&from-json
    };
    $!proc.stderr.tap: { warn $_                         };
    $!promise = $!proc.start;
}

method kill { $!proc.kill; }
