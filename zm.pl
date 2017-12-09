#!/usr/bin/env perl

=head1 NAME

zm2 - CLI client for Zonemaster::Backend

=head1 SYNOPSIS

zm2 --help|--man

zm2 command [command_options]

 Options:
   --help  Brief help message
   --man   Full documentation

=cut

use strict;
use warnings;
use feature 'say';

use Getopt::Long qw( GetOptionsFromArray :config require_order );
use Pod::Usage;

use JSON::PP;
use LWP::UserAgent;

my @myopts = @ARGV;

sub main {
    my @myopts = @_;

    my $opt_help;
    my $opt_man;

    GetOptionsFromArray(
        \@myopts,
        'help' => \$opt_help,
        'man' => \$opt_man,
    ) or pod2usage(2);

    pod2usage(1) if $opt_help;
    pod2usage(-verbose => 2) if $opt_man;
    pod2usage(1) if !@myopts;

    my $cmd = shift @myopts;
    my $cmd_sub = \&{ "cmd_" . $cmd };

    pod2usage("'$cmd' is not a command") if !defined &$cmd_sub;

    &$cmd_sub(@myopts);
}

sub cmd_version_info {
    my $json = to_jsonrpc(
        id => 1,
        method => 'version_info',
    );
    my $req = to_post($json);
    my $response = submit($req);
    say $response;
}

sub cmd_list {
    for my $name ( get_commands() ) {
        say $name;
    }
}

sub get_commands {
    no strict 'refs';

    return
      map { $_ =~ s/^cmd_//r }
      grep { $_ =~ /^cmd_/ } grep { defined &{"main\::$_"} } keys %{"main\::"};
}

sub to_jsonrpc {
    my %args = @_;
    my $id = $args{id};
    my $method = $args{method};

    my $request = {
        jsonrpc => 2.0,
        method => $method,
        id => $id,
    };
    if (exists $args{params}) {
        $request->{params} = $args{params};
    }
    return encode_json($request);
}

sub to_post {
    my $json = shift;

    my $req = HTTP::Request->new(POST => 'http://localhost:5000/');
    $req->content_type('application/json');
    $req->content($json);

    return $req;
}

sub submit {
    my $req = shift;

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);

    if ($res->is_success) {
        return $res->decoded_content;
    } else {
        die $res->status_line;
    }
}

main(@ARGV);
