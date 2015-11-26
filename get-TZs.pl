#!/usr/bin/env perl

use strict;
use warnings;
use Mojo::DOM;
use Mojo::Util qw/spurt/;
use Mojo::JSON qw/encode_json/;
use Mojo::UserAgent;
use 5.020;
use experimental 'postderef';

my $dom = Mojo::UserAgent->new->get('http://time.is/time_zones')->res->dom;

my @tzs;
for my $d ( $dom->find('.section')->each ) {
    my $tz = { offset => $d->at('h1')->all_text };
    my @countries = Mojo::DOM->new($d)
        ->wrap('<zof></zof>')->find('zof > * > div > ul > li ')->each;
    for my $cont_d ( @countries ) {
        my $name = $cont_d->children('a')->first->all_text;
        my @cities = $cont_d->find('li a')->map('all_text')->to_array->@*;
        push $tz->{countries}->@*, +{
            name   => $name,
            cities => \@cities,
        };
    }

    push @tzs, $tz;
}

spurt encode_json(\@tzs) => 'tzs.json';

__END__

<div class="section even">
    <h1>UTC-9</h1>
    <div class="cloud scloud w90">
        <ul>
            <li id="c10">
                <a class="s1 country multizone bold" href="French_Polynesia">French Polynesia</a>
                <ul>
                    <li><a class="s4" href="Rikitea">Rikitea</a></li>
                </ul>
            </li>
            <li id="c9">
                < class="s2 country multizone bold" href="United_States">United States</a>
                <ul>
                    <li><a class="s3 multizone" href="Alaska">Alaska</a></li>
                    <li><a class="s5" href="Anchorage">Anchorage</a></li>
                </ul>
            </li>
        </ul>
    </div>
</div>