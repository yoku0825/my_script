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
use UnazuSan;
use WebService::Slack::IncomingWebHook;

my $irc_config  = pit_get("irc");
my $slack_config= pit_get("slack");

my $irc= UnazuSan->new(
  %$irc_config,
  enable_ssl => 0
);

my $slack= WebService::Slack::IncomingWebHook->new(%$slack_config);
 
$irc->on_message(
  qw/(.)/ => sub
  {
    my ($receive, $match)= @_;

    my $msg_from= $receive->{from_nickname};
    my $msg_body= $receive->{message};
    $slack->post(
      text       => $msg_from . ":" . $msg_body,
      username   => "IRC#emergency1",
      icon_emoji => ":sushi:"
    );
  }
);

$irc->run;

