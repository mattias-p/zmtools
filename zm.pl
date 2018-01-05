#!/usr/bin/env perl

=head1 NAME

zm2 - CLI client for Zonemaster::Backend

=head1 SYNOPSIS

zm2 --help|--man|--list

zm2 command [command_options]

 Options:
   --help     Brief help message
   --man      Full documentation
   --list     List all commands
   --verbose  Show query

=head1 COMMANDS

=head2 version_info

=head2 start_domain_test

 Options:
   --domain DOMAIN_NAME
   --nameservers DOMAIN_NAME=IP_ADDRESS

=head2 get_test_history

 Options:
   --domain DOMAIN_NAME
   --nameservers true|false|null
   --offset COUNT
   --limit COUNT

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
    my $opt_list;
    my $opt_verbose;
    GetOptionsFromArray(
        \@myopts,
        'help' => \$opt_help,
        'man' => \$opt_man,
        'list' => \$opt_list,
        'verbose' => \$opt_verbose,
    ) or pod2usage(2);
    pod2usage(1) if $opt_help;
    pod2usage(-verbose => 2) if $opt_man;
    if ($opt_list) {
        for my $name ( get_commands() ) {
            say $name;
        }
        return;
    }
    pod2usage(1) if !@myopts;

    my $cmd = shift @myopts;
    my $cmd_sub = \&{ "cmd_" . $cmd };
    pod2usage("'$cmd' is not a command") if !defined &$cmd_sub;

    my $json = &$cmd_sub(@myopts);

    if ($json) {
        say $json if $opt_verbose;
        my $request = to_request($json);
        my $response = submit($request);
        say $response;
    }
}

sub cmd_version_info {
    return to_jsonrpc(
        id => 1,
        method => 'version_info',
    );
}

sub cmd_start_domain_test {
    my @opts = @_;

    my %opt_nameservers;
    my $opt_domain;
    GetOptionsFromArray(
        \@opts,
        'domain|d=s' => \$opt_domain,
        'nameserver|n=s' => \%opt_nameservers,
    ) or pod2usage(2);

    my %params = (
        domain => $opt_domain,
    );

    if (%opt_nameservers) {
        my @nameservers;
        for my $name ( keys %opt_nameservers ) {
            push @nameservers, {
                ns => $name,
                ip => $opt_nameservers{$name},
            };
        }
        $params{nameservers} = \@nameservers;
    }

    return to_jsonrpc(
        id => 1,
        method => 'start_domain_test',
        params => \%params,
    );
}

sub cmd_get_test_history {
    my @opts = @_;
    my $opt_nameservers;
    my $opt_domain;
    my $opt_offset;
    my $opt_limit;

    GetOptionsFromArray(
        \@opts,
        'domain|d=s' => \$opt_domain,
        'nameserver|n=s' => \$opt_nameservers,
        'offset|o=i' => \$opt_offset,
        'limit|l=i' => \$opt_limit,
    ) or pod2usage(2);

    my %params = (
        frontend_params => {
            domain => $opt_domain,
        },
    );

    if ( $opt_nameservers ) {
        $params{frontend_params}{nameservers} = json_tern($opt_nameservers);
    }

    if ( defined $opt_offset ) {
        $params{offset} = $opt_offset;
    }

    if ( defined $opt_limit ) {
        $params{limit} = $opt_limit;
    }

    return to_jsonrpc(
        id => 1,
        method => 'get_test_history',
        params => \%params,
    );
}

sub get_commands {
    no strict 'refs';

    return
      map { $_ =~ s/^cmd_//r }
      grep { $_ =~ /^cmd_/ } grep { defined &{"main\::$_"} } keys %{"main\::"};
}

sub json_tern {
    my $value = shift;
    if ( $value eq 'true' ) {
        return JSON::PP::true;
    } elsif ( $value eq 'false' ) {
        return JSON::PP::false;
    } elsif ( $value eq 'null' ) {
        return undef;
    } else {
        die "unknown ternary value";
    }
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

sub to_request {
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
