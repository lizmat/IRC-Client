use strict;
use warnings;
use JSON::Meth;
use 5.020;
use POE qw(Component::Server::IRC);

$|++;

my ($Port) = @ARGV;

my %config = (
    servername => 'simple.poco.server.irc',
    nicklen    => 15,
    network    => 'SimpleNET'
);

my $pocosi = POE::Component::Server::IRC->spawn( config => \%config );

POE::Session->create(
    package_states => [
        'main' => [qw(_start _default)],
    ],
    heap => { ircd => $pocosi },
);

$poe_kernel->run();

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $heap->{ircd}->yield('register', 'all');
    $heap->{ircd}->add_auth(mask => '*@*');
    $heap->{ircd}->add_listener(port => $Port);
    $heap->{ircd}->add_operator({
        username => 'moo',
        password => 'fishdont',
    });
}

sub _default {
    my ($event, @args) = @_[ARG0 .. $#_];
    say {
        event => $event,
        args  => \@args,
    }->$j;


 #    print "$event: ";
 #    for my $arg (@args) {
 #        if (ref($arg) eq 'ARRAY') {
 #            print "[", join ( ", ", @$arg ), "] ";
 #        }
 #        elsif (ref($arg) eq 'HASH') {
 #            print "{", join ( ", ", %$arg ), "} ";
 #        }
 #        else {
 #            print "'$arg' ";
 #        }
 #    }
 #
 #    print "\n";
 }
