#!/usr/bin/perl

########################################################################
# Copyright (C) 2016  yoku0825
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
use utf8;

use Config::Pit;
use WebService::Reactio;

my $config = pit_get("reactio");
my $reactio= WebService::Reactio->new(%{$config});

if ($#ARGV >= 0)
{
  foreach (@ARGV)
  {
    $reactio->create_incident($_, {notification_text => "$_ has occurred"});
  }
}
else
{
  print "You need to give more than one argument which will be subject.\n";
  usage();
}

exit 0;




sub usage
{
  print << "EOF";
$0 is simple incident make for reactio.

  $0 "Subject of new creating issue"
EOF
}
