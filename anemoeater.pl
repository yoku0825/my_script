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
use Getopt::Long qw/:config posix_default bundling no_ignore_case gnu_compat/;

my $opt= {};
GetOptions($opt, qw/socket=s host=s port=i user=s password=s/) or die;

my $pt_dsn= "D=slow_query_log";
$pt_dsn  .= sprintf(",h=%s", $opt->{host})     if $opt->{host};
$pt_dsn  .= sprintf(",P=%d", $opt->{port})     if $opt->{port};
$pt_dsn  .= sprintf(",u=%s", $opt->{user})     if $opt->{user};
$pt_dsn  .= sprintf(",p=%s", $opt->{password}) if $opt->{password};


my $cmd_format= qq{| pt-query-digest --review %s --history %s --no-report --limit=0%% --filter="\\\$event->{Bytes} = length(\\\$event->{arg}) and \\\$event->{hostname}='%s'"};
my $cmd=  sprintf($cmd_format,
                  $pt_dsn . ",t=global_query_review",
                  $pt_dsn . ",t=global_query_review_history",
                  $ENV{HOSTNAME});

my $file= $ARGV[0];
open(my $in, "<", $file);

my ($time, @buffer);
while (<$in>)
{
  if (/^# Time:/)
  {
    if ($time)
    {
      open(my $process, sprintf($cmd_format,
                                $pt_dsn . ",t=global_query_review",
                                $pt_dsn . ",t=global_query_review_history",
                                $ENV{HOSTNAME}));
      print $process @buffer;
      close($process);

      $time  = 0;
      @buffer= ();
    }
  }

  $time= 1;
  push(@buffer, $_);
}

exit 0;


sub usage
{
  print << "EOF";
$0 [--user=s] [--password=s] [--port=i] [--host=s] [--socket=s] path_to_slowlog

  $0 is split slowlog and process by pt-query-digest.
  pt-query-digest's output will send to MySQL which is specified by options.
EOF
}
