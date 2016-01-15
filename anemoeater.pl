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

use Parallel::ForkManager;
use Getopt::Long qw/:config posix_default bundling no_ignore_case gnu_compat/;

my $opt= {parallel => 1,
          since    => 0,
          until    => 999912312359,
          report   => 0,
          docker   => 0};
GetOptions($opt, qw/socket=s host=s port=i user=s password=s
                    parallel=i since=s until=s report=i docker/) or die;

### Starting docker container.
if ($opt->{docker})
{
  my $container_id= `sudo docker run -d -P yoku0825/anemometer`;
  chomp($container_id);

  my $container_ipaddr= `sudo docker inspect -f '{{.NetworkSettings.IPAddress}}' $container_id`;
  chomp($container_ipaddr);

  ### wait container's mysqld starts to run
  sleep 3;

  $opt->{host}    = $container_ipaddr;
  $opt->{user}    = "anemometer";
  $opt->{password}= undef;
  $opt->{port}    = undef;
}

my $pt_dsn= "D=slow_query_log";
$pt_dsn  .= sprintf(",h=%s", $opt->{host})     if $opt->{host};
$pt_dsn  .= sprintf(",P=%d", $opt->{port})     if $opt->{port};
$pt_dsn  .= sprintf(",u=%s", $opt->{user})     if $opt->{user};
$pt_dsn  .= sprintf(",p=%s", $opt->{password}) if $opt->{password};

my $cmd_format= qq{| pt-query-digest --no-version-check --review %s --history %s --no-report --limit=0%% --filter="\\\$event->{Bytes} = length(\\\$event->{arg}) and \\\$event->{hostname}='%s'"};

my $pm  = Parallel::ForkManager->new($opt->{parallel});
my $file= $ARGV[0];
open(my $in, "<", $file);

my $event  = 0;
my $time   = 0;
my $timetmp= 0;
my @buffer = ();
while (<$in>)
{
  if (/^# Time: (?<timestr>.+)$/)
  {
    if ($+{timestr} =~ /(?<year>\d{2})(?<month>\d{2})(?<day>\d{2})\s+
                        (?<hour>\d{1,2}):(?<minute>\d{2}):(?<second>\d{2})/x)
    {
      ### 5.0, 5.1, 5.5, 5.6 style.
      # "# Time: %02d%02d%02d %2d:%02d:%02d\n",

      ### normalize without seconds.
      $timetmp= sprintf("20%02d%02d%02d%02d%02d",
                        $+{year}, $+{month}, $+{day},
                        $+{hour}, $+{minute});
    }
    elsif ($+{timestr} =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})T
                           (?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})\.
                           (?<fraction>\d{6})(?<timezone>.*)/x)
    {
      ### 5.7 style.
      # "%04d-%02d-%02dT%02d:%02d:%02d.%06lu%s",
 
      ### normalize without seconds.
      $timetmp= sprintf("%04d%02d%02d%02d%02d",
                        $+{year}, $+{month}, $+{day},
                        $+{hour}, $+{minute});
    }
    else
    {
      ### Unknown format.
      $timetmp= 0;
    }

    if ($timetmp != $time)
    {
      &send_pt_qd if ($opt->{since} <= $time && $time <= $opt->{until});
      $time= $timetmp;
      @buffer= ();
    }
  }
  push(@buffer, $_);
}

### flush last block.
&send_pt_qd if (@buffer && $opt->{since} <= $time && $time <= $opt->{until});

$pm->wait_all_children;

exit 0;


sub usage
{
  print << "EOF";
$0 [--user=s] [--password=s] [--port=i] [--host=s] [--socket=s]
   [--parallel=i] [--since=i] [--until=i] [--report=i] path_to_slowlog
  $0 is split slowlog and process by pt-query-digest.

  --user=s     MySQL user which pt-query-digest uses to connection.
  --password=s MySQL password which pt-query-digest uses to connection.
  --port=i     MySQL port which pt-query-digest uses to connection.
  --host=s     MySQL host which pt-query-digest uses to connection.
  --socket=s   MySQL socket which pt-query-digest uses to connection.
  --parallel=i How many processes does script run concurrently.
  --since=i    Filter for processing slow-log, YYYYMMDDHHNN style only.
  --until=i    Filter for processing slow-log, YYYYMMDDHHNN style only.
  --report=i   Print message each processed events n times.
EOF
}


sub send_pt_qd
{
  printf("processing %dth event.\n", $event) if ($opt->{report} && (++$event % $opt->{report}) == 0);

  unless ($pm->start)
  {
    open(my $process, sprintf($cmd_format,
                              $pt_dsn . ",t=global_query_review",
                              $pt_dsn . ",t=global_query_review_history",
                              $ENV{HOSTNAME}));
    print $process @buffer;
    close($process);
    $pm->finish;
  }
} 
