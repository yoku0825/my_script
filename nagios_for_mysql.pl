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
use DBI;
use Getopt::Long qw/:config bundling no_ignore_case posix_default/;

### return values to Nagios.
use constant NAGIOS_OK       => 0;
use constant NAGIOS_WARNING  => 1;
use constant NAGIOS_CRITICAL => 2;
use constant NAGIOS_UNKNOWN  => 3;

GetOptions("user=s"       => \my $user,
           "port=i"       => \my $port,
           "password=s"   => \my $password,
           "socket=s"     => \my $socket,
           "sql=s"        => \my $sql,
           "warning=i"    => \my $warning,
           "critical=i"   => \my $critical,
           "threshold=i"  => \my $threshold,
           "host=s"       => \my $host,
           "usage|h|help" => \my $usage);
if ($usage)
{
  usage();
  exit NAGIOS_OK;
}

### --user, --host, --sql need to specified.
if (!($user) || !($host) || !($sql))
{
  usage();
  exit NAGIOS_UNKNOWN;
}

### set implicit default values.
$threshold= 10  if (!(defined($threshold)));
$warning  = 10  if (!(defined($warning)));
$critical = 100 if (!(defined($critical)));


my $dsn= "dbi:mysql:information_schema";
$dsn .= ":$host"                if ($host);
$dsn .= ";mysql_socket=$socket" if ($socket);
$dsn .= ";port=$port"           if ($port);

my $conn = DBI->connect($dsn, $user, $password) or exit NAGIOS_CRITICAL;
my $count= 0;

### $count stores only one value,
### even if result set has more than 2 columns and/or 2 rows.
eval
  {$count= $conn->selectrow_arrayref($sql)->[0];};
if ($@)
  {exit NAGIOS_UNKNOWN;}

if ($count > $critical)
  {exit NAGIOS_CRITICAL;}
elsif ($count > $warning)
  {exit NAGIOS_WARNING;}
else
  {exit NAGIOS_OK;}

exit NAGIOS_UNKNOWN;


sub usage
{
  print << "EOS";
$0 is customizeable MySQL check script for Nagios by SQL.

mandatory options:
  --user=user           user which uses for login to MySQL.
  --host=host           hostname or IP address of MySQL Server.
  --sql=SQL             SQL statement which executes on MySQL.
                        This have to return only one row int type value.

additional options:
  --password=password   password which uses for login to MySQL (default: "")
  --port=port           port number of MySQL Server (default: depends on DBD::mysql)
  --socket=path         path of socket file of MySQL Server (default: depends on DBD::mysql)
                        This value effects only --host=localhost.
  --warning=number      threshold of WARNING state (default: 10)
                        This script returns 1, if SQL returns over than this number.
  --critical=number     threshold of CRITICAL state (default: 100)
                        This script returns 2, if SQL returns over than this number.
EOS
  return 0;
}

