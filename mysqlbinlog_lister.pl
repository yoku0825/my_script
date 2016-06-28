#!/usr/bin/perl

########################################################################
# Copyright (C) 2014, 2016  yoku0825
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
use Getopt::Long qw/:config bundling gnu_compat no_ignore_case posix_default/;

### aggrigation unit. "h|hour" => per hour, "m|minute" => per minute, "s|second" => per second.
my $cell    = "10m";
my $group_by= "time";
GetOptions("cell=s"       => \$cell,
           "group-by=s"   => \$group_by,
           "save"         => \my $save,
           "help|usage|h" => \my $usage) or die;
usage() if $usage;
my ($header_parser, $print_format)= set_parser($cell);

my $save_file= "mysqlbinlog_save.txt";
my ($time_string, $count_hash, $sum, $fh);
open($fh, ">", $save_file) if $save;

### read from stdin.
while (<>)
{
  print $fh $_ if $save;
  ### parsing datetime from comment line.
  if (/$header_parser/)
  {
    $time_string= $1;
  }

  ### parsing dml-line (only parse simple INSERT, UPDATE, DELETE, REPLACE)
  elsif (/^(insert|update|delete|replace)\s+(?:(?:into|from)?)\s+(\S+?)\s+/i)
  {
    my ($dml, $table)= (lc($1), lc($2));
    $table =~ s/`//g;
    if ($table =~ /([^\(]+)\(/)
    {
      $table= $1;
    }

    if ($time_string && $dml && $table)
    {
      if ($group_by eq "all" || $group_by eq "time,table,statement")
      {
        $count_hash->{$time_string}->{$table}->{$dml}++;
      }
      elsif ($group_by eq "time,table")
      {
        $count_hash->{$time_string}->{$table}++;
      }
      elsif ($group_by eq "time")
      {
        $count_hash->{$time_string}++;
      }
      elsif ($group_by eq "table")
      {
        $count_hash->{$table}++;
      }
      elsif ($group_by eq "statement")
      {
        $count_hash->{$dml}++;
      }
      elsif ($group_by eq "time,statement")
      {
        $count_hash->{$time_string}->{$dml}++;
      }
      elsif ($group_by eq "table,statement")
      {
        $count_hash->{$table}->{$dml}++;
      }
        
      $time_string= $dml= $table= "";
    }
  }
}

### after reading all lines, printing them all.
if ($group_by eq "table" || $group_by eq "statement")
{
  ### Only have 1 element.
  foreach my $element (sort(keys(%$count_hash)))
  {
    printf("%s\t%d\n", $element, $count_hash->{$element});
  }
}
elsif ($group_by eq "table,statement")
{
  ### Have 2 elements without "time"
  foreach my $table (sort(keys(%$count_hash)))
  {
    foreach my $dml (sort(keys(%{$count_hash->{$table}})))
    {
      printf("%s\t%s\t%d\n", $table, $dml, $count_hash->{$table}->{$dml});
    }
  }
}
else
{
  ### starting with "time"
  foreach my $time (sort(keys(%$count_hash)))
  {
    my $time_printable= sprintf($print_format, $time);

    if ($group_by eq "time")
    {
      printf("%s\t%d\n", $time_printable, $count_hash->{$time});
    }
    elsif ($group_by eq "time,table" || $group_by eq "time,statement")
    {
      foreach my $element (sort(keys(%{$count_hash->{$time}})))
      {
        printf("%s\t%s\t%d\n", $time_printable, $element, $count_hash->{$time}->{$element});
      }
    }
    elsif ($group_by eq "all" || $group_by eq "time,table,statement")
    {
      foreach my $table (sort(keys(%{$count_hash->{$time}})))
      {
        foreach my $dml (sort(keys(%{$count_hash->{$time}->{$table}})))
        {
          printf("%s\t%s\t%s\t%d\n", $time_printable, $table, $dml, $count_hash->{$time}->{$table}->{$dml});
        }
      }
    }
  }
}

printf("stdin was saved on %s\n", $save_file) if $save;

exit 0;


### set regexp for parsing datetime.
sub set_parser
{
  my ($granuality)= @_;
  my ($parse, $format);

  if ($granuality eq "h" || $granuality eq "hour")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}):\d{2}:\d{2}/;
    $format= "%s:00";
  }
  elsif ($granuality eq "m" || $granuality eq "minute" || $granuality eq "1m")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}):\d{2}/;
    $format= "%s";
  }
  elsif ($granuality eq "10m")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{1})\d{1}:\d{2}/;
    $format= "%s0";
  }
  elsif ($granuality eq "10s")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}:\d{1})\d{1}/;
    $format= "%s0";
  }
  else # same as ($granuality eq "s" || $granuality eq "second")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}:\d{2})/;
    $format= "%s";
  }

  return ($parse, $format);
}


sub usage
{
  print << "EOS";
$0 is aggregator of mysqlbinlog's output.

expample:
  \$ mysqlbinlog --start-datetime="2012-03-04" --stop-datetime="2012-03-05" mysql-bin.000012 | $0 --cell m --group-by="time,statement"
  ..
  140823 23:36    insert  57
  140823 23:36    update  580
  140823 23:36    replace 5
  140823 23:37    insert  86
  140823 23:37    update  520
  140823 23:37    replace 6
  140823 23:38    insert  87
  140823 23:38    update  671
  140823 23:38    replace 6
  ..

options:
  --cell=string         Unit of aggregation. [default: 10m]
                        Currentry supported are,
                          "s", "second",
                          "m", "minute", "1m",
                          "10m", 
                          "h", "hour"
  --group-by=string     Part of aggregation. [default: time]
                          "time", "table", "statement",
                          "time,table", "time,statement", "table,statement",
                          "all", "time,table,statement" (same as "all")
  --save                Save scrpit's stdin(mysqlbinlog's stdout) into $save_file
  --usage, --help, -h   Print this message.
EOS
  exit 0;
}
