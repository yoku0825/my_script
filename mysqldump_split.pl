#!/usr/bin/perl

########################################################################
# Copyright (C) 2014  yoku0825
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
use Fcntl;

my $db;
while (my $line= <>)
{
  if ($line =~ /^CREATE DATABASE.*\s`(\S+)`;/)
    {$db= $1;}

  next unless $db;
  sysopen(my $fh, $db, O_WRONLY|O_APPEND|O_CREAT) or die;
  print $fh $line;
  close($fh);
}

exit 0;
