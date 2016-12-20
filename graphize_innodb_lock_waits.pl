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

use DBI;
use Graph::Easy;
use Getopt::Long qw/:config posix_default bundling no_ignore_case gnu_compat/;

my $opt=
{
  socket   => undef,
  host     => "localhost",
  port     => undef,
  user     => undef,
  password => "",
};
GetOptions($opt, qw/socket=s host=s port=i user=s password=s/) or die;

my $dsn= "dbi:mysql:sys";
$dsn  .= sprintf(";host=%s", $opt->{host}) if $opt->{host};
$dsn  .= sprintf(";port=%d", $opt->{port}) if $opt->{port};
$dsn  .= sprintf(";mysql_socket=%s", $opt->{socket}) if $opt->{socket};

my $conn= DBI->connect($dsn, $opt->{user}, $opt->{password},
                       {RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1}) or die;
my $sql = "SELECT wait_age_secs, waiting_trx_id, waiting_query, blocking_trx_id, blocking_query " .
          "FROM sys.innodb_lock_waits";
my $graph= Graph::Easy->new;

foreach my $row (@{$conn->selectall_arrayref($sql, {Slice => {}})})
{
  my $waiting = $graph->node($row->{blocking_trx_id}) ? $graph->node($row->{blocking_trx_id}) : $graph->add_node($row->{waiting_trx_id});
  $waiting->set_attributes({label => $row->{waiting_query} ? $row->{waiting_query} : ""});
  $waiting->set_attributes({color => "red"}) if $row->{wait_age_secs} > 1;

  my $blocking= $graph->node($row->{blocking_trx_id}) ? $graph->node($row->{blocking_trx_id}) : $graph->add_node($row->{blocking_trx_id});
  $waiting->set_attributes({label => $row->{blocking_query} ? $row->{blocking_query} : ""});

  $graph->add_edge($waiting, $blocking);
}

print $graph->as_svg;
exit 0;
