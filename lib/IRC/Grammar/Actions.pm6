unit class IRC::Grammar::Actions:ver<1.001001>;
method TOP ($/) { $/.make: $<message>>>.made }
method message ($/) {
    my $pref = $/<prefix>;
    my %args = command => ~$/<command>;
    for qw/nick user host/ {
        $pref{$_}.defined or next;
        %args<who>{$_} = $pref{$_}.Str;
    }
    %args<who><host> = ~$pref<servername> if $pref<servername>.defined;

    my $p = $/<params>;
    loop {
        if ( $p<middle>.defined ) {
            %args<params>.append: ~$p<middle>;
        }
        if ( $p<trailing>.defined ) {
            %args<params>.append: ~$p<trailing>;
            last;
        }
        $p = $p<params>;
    }

    $/.make: %args;
}
