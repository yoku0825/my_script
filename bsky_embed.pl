#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.014;

use Encode qw(encode_utf8);
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Tiny;
use JSON::PP qw(decode_json);
use Time::Piece;

my $VERSION = '0.1.0';

sub usage {
    return <<"USAGE";
Usage: $0 [--handle <handle> | --url <profile-url>] [--since <date>] [--until <date>]

Options:
  --handle  Bluesky handle (e.g. yoku0825.bsky.social)
  --url     Bluesky profile URL (e.g. https://bsky.app/profile/yoku0825.bsky.social)
  --since   Start date (inclusive), YYYY-MM-DD or ISO-8601 (default: 24 hours ago)
  --until   End date (exclusive), YYYY-MM-DD or ISO-8601 (default: now)
  --help    Show this help

Example:
  $0 --url https://bsky.app/profile/yoku0825.bsky.social --since 2024-01-01 --until 2024-02-01
USAGE
}

sub parse_epoch {
    my ($str) = @_;

    $str =~ s/\.\d+Z\z/Z/;
    $str .= 'T00:00:00Z' if $str =~ /^\d{4}-\d{2}-\d{2}\z/;

    if ($str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/) {
        return Time::Piece->strptime($str, '%Y-%m-%dT%H:%M:%SZ')->epoch;
    }

    die "Invalid date/time format: $str\n";
}

sub extract_handle {
    my ($url) = @_;
    if ($url =~ m{^https?://bsky\.app/profile/([^/]+)/?}i) {
        return $1;
    }
    die "Invalid Bluesky profile URL: $url\n";
}

sub build_api_url {
    my ($handle, $cursor) = @_;
    my $url = "https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=${handle}&limit=100";
    $url .= "&cursor=${cursor}" if defined $cursor;
    return $url;
}

sub fetch_feed {
    my ($handle) = @_;
    my $http = HTTP::Tiny->new(
        agent      => "bsky_embed.pl/${VERSION}",
        timeout    => 30,
        verify_SSL => 1,
    );

    my @posts;
    my $cursor;

    while (1) {
        my $url = build_api_url($handle, $cursor);
        my $res = $http->get($url);

        die "HTTP error: $res->{status} $res->{reason}\n" unless $res->{success};

        my $data = eval { decode_json($res->{content}) }
            or die "Failed to parse JSON response\n";

        push @posts, @{ $data->{feed} // [] };

        $cursor = $data->{cursor};
        last unless defined $cursor && @{ $data->{feed} // [] };
    }

    return \@posts;
}

sub is_in_range {
    my ($post, $since_epoch, $until_epoch) = @_;
    my $created_at = $post->{post}{record}{createdAt}
        or return 0;

    my $epoch = eval { parse_epoch($created_at) };
    return 0 unless defined $epoch;

    return $epoch >= $since_epoch && $epoch < $until_epoch;
}

sub extract_rkey {
    my ($uri) = @_;
    if ($uri =~ m{/app\.bsky\.feed\.post/([^/]+)\z}) {
        return $1;
    }
    return '';
}

sub format_datetime {
    my ($created_at) = @_;
    return '' unless $created_at;

    (my $dt_str = $created_at) =~ s/\.\d+Z\z/Z/;
    $dt_str .= 'T00:00:00Z' if $dt_str =~ /^\d{4}-\d{2}-\d{2}\z/;

    my $dt = eval { Time::Piece->strptime($dt_str, '%Y-%m-%dT%H:%M:%SZ') };
    return $dt ? $dt->strftime('%Y-%m-%d %H:%M:%S UTC') : $created_at;
}

sub build_embed_html {
    my ($post) = @_;
    my $uri    = $post->{post}{uri}        // '';
    my $cid    = $post->{post}{cid}        // '';
    my $author = $post->{post}{author}{handle} // '';
    my $text   = $post->{post}{record}{text}   // '';
    my $rkey   = extract_rkey($uri);
    my $url    = "https://bsky.app/profile/${author}/post/${rkey}";

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\n/<br>\n/g;

    my $display_date = format_datetime($post->{post}{record}{createdAt} // '');

    return <<"HTML";
<blockquote class="bluesky-embed" data-bluesky-uri="$uri" data-bluesky-cid="$cid">
  <p lang="ja">$text<br>
  <a href="$url">$display_date</a></p>
</blockquote>
HTML
}

sub main {
    my (@args) = @_;

    my ($handle, $url, $since_str, $until_str, $help);
    GetOptionsFromArray(\@args,
        'handle=s' => \$handle,
        'url=s'    => \$url,
        'since=s'  => \$since_str,
        'until=s'  => \$until_str,
        'help|h'   => \$help,
    ) or die usage();

    if ($help) {
        print usage();
        return 0;
    }

    die "--handle or --url is required\n" . usage()
        unless defined $handle || defined $url;

    $handle = extract_handle($url) if defined $url;

    my $now = time();
    my $since_epoch = defined $since_str ? parse_epoch($since_str) : $now - 24 * 60 * 60;
    my $until_epoch = defined $until_str ? parse_epoch($until_str) : $now;

    die "--since must be earlier than --until\n" unless $since_epoch < $until_epoch;

    my $feed = fetch_feed($handle);

    my @matched = grep { is_in_range($_, $since_epoch, $until_epoch) } @$feed;

    if (!@matched) {
        warn "No posts found in the specified period.\n";
        return 0;
    }

    for my $post (@matched) {
        print encode_utf8(build_embed_html($post));
    }

    print encode_utf8(<<'SCRIPT');
<script async src="https://embed.bsky.app/static/embed.js" charset="utf-8"></script>
SCRIPT

    return 0;
}

exit main(@ARGV);
