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
use DBI;
use Fluent::Logger;
use Getopt::Long qw/:config posix_default bundling no_ignore_case gnu_compat/;

GetOptions("S|socket=s" => \my $socket,
           "h|host=s"   => \my $host,
           "P|port=i"   => \my $port,
           "i|interval=i" => \my $interval) or die;
my %fluent_opt;
$fluent_opt{socket}= $socket if $socket;
$fluent_opt{host}  = $host   if $host;
$fluent_opt{port}  = $port   if $port;
my $fluent     = Fluent::Logger->new(%fluent_opt);

$interval= 5 unless $interval;
my $mysql_instances;

foreach my $mysql_info (@ARGV)
{
  my $dsn     = "dbi:mysql:information_schema";
  $mysql_info =~ /^(?<ident>[^\/]*)
                   \/?
                   (?<user>\w+)
                   :?
                   (?<password>.*)
                   @
                   (?<host>[\w\.\-]+)
                   :?
                   (?<port>\d*)/x;
  $dsn       .= ";host=$+{host}" if $+{host};
  $dsn       .= ";port=$+{port}" if $+{port};

  if ($mysql_instances->{$dsn})
  {
    printf("DSN %s is already registered.\n", $dsn);
  }
  else
  {
    my $ident= $+{ident} ? $+{ident} : $dsn;
    $mysql_instances->{$dsn}= {ident => $ident,
                               conn => DBI->connect($dsn, $+{user}, $+{password}),
                               new => {}, prev => {}};
  }
}
exit 0 unless ($mysql_instances);

my $status_sql = "SELECT lower(variable_name) AS name, variable_value AS value " .
                 "FROM global_status WHERE variable_value RLIKE '^[0-9]+\$' ORDER BY name";
my $process_sql= "SELECT id, user, host, db, command, time, state, info " .
                 "FROM processlist";

while ()
{
  foreach my $dsn (keys(%$mysql_instances))
  {
    my $current_status;
    my $mysql= $mysql_instances->{$dsn};
  
    foreach my $row (@{$mysql->{conn}->selectall_arrayref($status_sql, {Slice => {}})})
    {
      my $name= $row->{name};
      $mysql->{prev}->{$name}= $mysql->{new}->{$name};
      $mysql->{new}->{$name} = $row->{value};
      $current_status->{$name} = ($mysql->{new}->{$name} - $mysql->{prev}->{$name}) / $interval
                                 if defined($mysql->{prev}->{$name});
    }
    $fluent->post("mysql.status", {$mysql->{ident} => {%$current_status}}) or die $fluent->strerr if $current_status;
    sleep $interval;
  }
}

exit 0;
