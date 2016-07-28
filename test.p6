
my @s = %( :host<localhost>,   :6667port, :promise(''), :sock(''), :!q, :0e ),
        %( :host<localhost>,   :4444port, :promise(''), :sock(''), :!q, :0e );

my Channel $c .= new;

sub connect-it ($s) {
    say "Connecting $s<host>:$s<port>";
    $s<sock> = '';
    $s<promise> = IO::Socket::Async.connect(|$s<host port>).then: sub ($_) {
        if .status ~~ Broken {
            dd "ZOMFG! Can't connect!";
            $s<q> = True if $s<e>++ > 4;
            sleep 1;
            $c.send: ['broken', $s];
            return;
        }

        $s<sock> = .result;
        react {
            say "Loooop";
            whenever $s<sock>.Supply {
                say "Got stuff! $_";
            }
        }
        $s<q> = True if $s<e>++ > 3;
        $c.send: ['closed', $s];
        CATCH { default { warn $_; warn .backtrace; } }
    }
}

connect-it $_ for @s;
loop {
    say "Starting listen";
    my $v = $c.receive;
    dd $v;
    connect-it $v[1] unless $v[1]<q>;
    unless @s.grep({!.<q>}) {
        say 'Bailing out';
        last;
    }
}
