use IRC::Client:ver<4.0.5>:auth<zef:lizmat>;

sub EXPORT () { Map.new: ("IRC" => IRC) }

=begin pod

=head1 NAME

IRC::Client::Message - IRC::Client Message Types

=head1 SYNOPSIS

=begin code :lang<raku>

use IRC::Client::Message;

my constant ChannelMessage = IRC::Client::Message::Privmsg::Channel;

=end code

=head1 DESCRIPTION

This module provides the same interface as C<use IRC::Client::Message> used
to give.

=end pod

# vim: expandtab shiftwidth=4
