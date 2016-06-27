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
use Parallel::ForkManager;
use Fcntl;

### Detecting tpcc_load executable.
my $tpcc_load= "";
if (-x "./tpcc_load")
  {$tpcc_load= "./tpcc_load";}
elsif ($tpcc_load= `which tpcc_load 2>/dev/null`)
  {chomp($tpcc_load);}
else
{
  ### TODO: read from stdin.
  print STDERR "tpcc_load executable is not found.\n";
  exit 1;
}

### Detecting how many cores.
my $max_proc= 0;
sysopen(my $fh, "/proc/cpuinfo", O_RDONLY);
while (<$fh>)
{
  if (/^processor\s+:\s+(\d+)$/)
    {$max_proc++};
}

### TODO: read by getoptions
my $db_name  = "tpcc";
my $user     = "tpcc";
my $password = "test";
my $warehouse= 4;


system($tpcc_load . " localhost $db_name $user $password $warehouse 1 1 $warehouse");
my $pm= Parallel::ForkManager->new($max_proc);
foreach (my $n= 1; $n <= $warehouse; $n++)
{
  foreach (2..4)
  {
    $pm->start and next;
    system($tpcc_load . " localhost $db_name $user $password $warehouse $_ $n $n");
    $pm->finish;
  }
}
$pm->wait_all_children;


exit 0;

