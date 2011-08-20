package HTTP::Daemon::UNIX;

use 5.010;
use strict;
use warnings;

use HTTP::Daemon;
use IO::Handle::Record; # for peercred()
use IO::Socket::UNIX;
our @ISA = qw(HTTP::Daemon IO::Socket::UNIX);

our $VERSION = '0.03'; # VERSION

sub new {
    my ($class, %args) = @_;
    my $sock;

    # XXX normalize arg case first

    if ($args{Local}) {
        my $path = $args{Local};

        # probe the Unix socket first, delete if stale
        $sock = IO::Socket::UNIX->new(
            Type=>SOCK_STREAM,
            Peer=>$path);
        my $err = $@ unless $sock;
        if ($sock) {
            die "Some process is already listening on $path, aborting";
        } elsif ($err =~ /^connect: permission denied/i) {
            # XXX language dependant
            die "Cannot access $path, aborting";
        } elsif (1) { #$err =~ /^connect: connection refused/i) {
            # XXX language dependant
            unlink $path;
        } elsif ($err !~ /^connect: no such file/i) {
            # XXX language dependant
            die "Cannot bind to $path: $err";
        }
    }

    $args{Listen} //= 1;
    $args{Type}   //= SOCK_STREAM;

    $sock = IO::Socket::UNIX->new(%args);
    die "Can't bind to Unix socket: $@" unless $sock;
    bless $sock, $class;
}

sub url {
    my ($self) = @_;
    my $hostpath = $self->hostpath;
    $hostpath =~ s!^/!!;
    my $url = $self->_default_scheme . ":" . $hostpath;

    # note: my LWP::Protocol::http::SocketUnixAlt requires this syntax ("//"
    # separates the Unix socket path and URI):
    # http:abs/path/to/unix.sock//uri/path
}

1;


=pod

=head1 NAME

HTTP::Daemon::UNIX - HTTP::Daemon over Unix sockets

=head1 VERSION

version 0.03

=head1 SYNOPSIS

 use HTTP::Daemon::UNIX;

 # arguments will be passed to IO::Socket::UNIX, but Listen=>1 and
 # Type=>SOCK_STREAM will be added by default. also, HTTP::Daemon::UNIX will try
 # to delete stale socket first, for convenience.
 my $d = HTTP::Daemon::UNIX->new(Local => "/path/to/unix.sock");

 # will print something like: "http:path/to/unix.sock"
 print "Please contact me at: <URL:", $d->url, ">\n";

 # after that, use like you would use HTTP::Daemon
 while (my $c = $d->accept) {
     while (my $r = $c->get_request) {
         if ($r->method eq 'GET' and $r->uri->path eq "/xyzzy") {
             # remember, this is *not* recommended practice :-)
             $c->send_file_response("/etc/passwd");
         } else {
             $c->send_error(RC_FORBIDDEN);
         }
     }
     $c->close;
     undef($c);
 }

 # client side code, using LWP::Protocol::http::SocketUnixAlt
 use LWP::Protocol::http::SocketUnixAlt;
 use LWP::UserAgent;
 use HTTP::Request::Common;

 my $ua = LWP::UserAgent->new;
 my $orig_imp = LWP::Protocol::implementor("http");
 LWP::Protocol::implementor(http => 'LWP::Protocol::http::SocketUnixAlt');
 my $resp = $ua->request(GET "http:path/to/unix.sock//uri/path");
 LWP::Protocol::implementor(http => $orig_imp);

=head1 DESCRIPTION

This is a quick hack to enable L<HTTP::Daemon> to serve requests over Unix
sockets, by mixing in L<IO::Socket::UNIX> and HTTP::Daemon as parents to
L<HTTP::Daemon::UNIX> and overriding IO::Socket::INET-related stuffs.

Basic stuffs seem to be working, but this module has not been tested
extensively, so beware that things might blow up in your face.

=head1 SEE ALSO

L<HTTP::Daemon>

L<LWP::Protocol::http::SocketUnixAlt>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__
# ABSTRACT: HTTP::Daemon over Unix sockets

