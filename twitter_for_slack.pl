#!/usr/bin/perl

########################################################################
# Copyright (C) 2015  yoku0825
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
########################################################################

use strict;
use warnings;
use Config::Pit;
use Net::Twitter::Lite::WithAPIv1_1;
use WebService::Slack::IncomingWebHook;
use utf8;
use Encode;
use FindBin qw/$Bin/;
binmode STDIN,  ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";

my $query  = decode("utf8", $ARGV[0]);
$query     = &pick_keyword unless $query;

my $history= "$Bin/." . $query . "_history";
my $fh;

system("touch $history");
open($fh, "< $history");
my @histories= <$fh>;
close($fh);
open($fh, ">> $history");

my $twitter_config= pit_get("twitter");
my $slack_config  = pit_get("slack_nico");

my $twitter= Net::Twitter::Lite::WithAPIv1_1->new(
  %$twitter_config,
  ssl => 1);
my $slack  = WebService::Slack::IncomingWebHook->new(
  webhook_url => $slack_config->{incoming_url});

my $result= $twitter->search({q => "-RT $query", lang => "ja", count => 20});
foreach my $tweet (@{$result->{statuses}})
{
  if (my $url= $tweet->{entities}->{media}->[0]->{media_url})
  {
    my $original_tweet= sprintf("https://twitter.com/%s/status/%d",
                                $tweet->{user}->{screen_name},
                                $tweet->{id});
    next if grep {/$original_tweet/} @histories;

    $slack->post(
      text       => $original_tweet,
      username   => $query,
      icon_emoji => ":conoha:");
    print($fh $original_tweet, "\n");
    close($fh);
    exit 0;
  }
}

$slack->post(
  text       => "残念、$query の画像はなかった。少なくともパッと見では。\nhttps://pbs.twimg.com/profile_images/2591998236/20120301121746_126_1.jpg",
  username   => $query,
  icon_emoji => ":sayaka:");
close($fh);

exit 0;


sub pick_keyword
{
  no warnings "qw";
  my @keywords= qw/#鬱な気分が吹っ飛ぶ画像ください
                   #社畜ちゃん台詞メーカー
                   #いま自分がもってる意味不明な画像を晒せ
                   from:cinnamon_sanrio
                   #ナナピク
                   #ウチ姫ファンアート
                   from:matumoto_izumi
                   #飯テロ/;
  return $keywords[int(rand($#keywords + 1))];
}
