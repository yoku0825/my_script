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
use Getopt::Long qw/:config bundling gnu_compat no_ignore_case posix_default/;
use Fcntl;

GetOptions("help|usage|h" => \my $usage) or die;
usage() if $usage;

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


sub usage
{
  print << "EOS";
$0 is spliter of mysqldump's output.

expample:
  \$ mysqldump --all-databases --single-transaction | mysqldump_split.pl
  \$ ls -l
  .. (you get a list of each databases' dump)

options:
  --usage, --help, -h   Print this message.
EOS
  exit 0;
}

