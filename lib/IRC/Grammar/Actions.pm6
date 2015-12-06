unit class IRC::Grammar::Actions:ver<1.001001>;
method TOP ($/) { $/.make: $<message>>>.made }
method message ($/) {
    my $pref = $/<prefix>;
    my %args = command => ~$/<command>;
    if ( $pref<servername>.defined ) {
        %args<who><host> = ~$pref<servername>;
    }
    else {
        %args<who><nick user host> = $pref<nick  user  host>».Str;
    }

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
