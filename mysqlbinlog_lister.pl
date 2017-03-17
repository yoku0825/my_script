#!/usr/bin/perl

########################################################################
# Copyright (C) 2014, 2017  yoku0825
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
my $output  = "tsv";
GetOptions("cell=s"       => \$cell,
           "group-by=s"   => \$group_by,
           "save"         => \my $save,
           "output=s"     => \$output,
           "help|usage|h" => \my $usage) or die;
usage() if $usage;

### normalize group-by string
$group_by= sort_csv($group_by);

my ($header_parser, $print_format)= set_parser($cell);
usage("--cell=$cell is invalid") unless $header_parser;

my $save_file= "mysqlbinlog_save.txt";
my ($time_string, $count_hash, $sum, $fh, $first_seen, $last_seen);
open($fh, ">", $save_file) if $save;

### read from stdin.
while (<>)
{
  print $fh $_ if $save;
  ### parsing datetime from comment line.
  if (/$header_parser/)
  {
    $time_string= $1;
    $first_seen = $time_string unless $first_seen;
    $last_seen  = $time_string;
  }

  ### parsing dml-line (only parse simple INSERT, UPDATE, DELETE, REPLACE)
  elsif (/^(insert|update|delete|replace)\s+(?:ignore\s+)?(?:(?:into|from)?\s+)?(\S+?)\s+/i ||
         /^###\s+(INSERT|UPDATE|DELETE)\s+(?:(?:INTO|FROM)?\s+)?(\S+)/)
  {
    my ($dml, $table)= (uc($1), lc($2));
    $table =~ s/`//g;
    if ($table =~ /([^\(]+)\(/)
    {
      $table= $1;
    }

    if ($time_string && $dml && $table)
    {
      if ($group_by eq "all" || $group_by eq sort_csv("time,table,statement"))
      {
        $count_hash->{$time_string}->{$table}->{$dml}++;
      }
      elsif ($group_by eq sort_csv("time,table"))
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
      elsif ($group_by eq sort_csv("time,statement"))
      {
        $count_hash->{$time_string}->{$dml}++;
      }
      elsif ($group_by eq sort_csv("table,statement"))
      {
        $count_hash->{$table}->{$dml}++;
      }
        
      $time_string= $dml= $table= "";
    }
  }
}

printf("binlog entries between %s and %s\n",
       sprintf($print_format, $first_seen),
       sprintf($print_format, $last_seen));

### after reading all lines, printing them all.
if ($group_by eq "table" || $group_by eq "statement")
{
  ### Only have 1 element.
  foreach my $element (sort(keys(%$count_hash)))
  {
    write_line($element, $count_hash->{$element});
  }
}
elsif ($group_by eq sort_csv("table,statement"))
{
  ### Have 2 elements without "time"
  foreach my $table (sort(keys(%$count_hash)))
  {
    foreach my $dml (sort(keys(%{$count_hash->{$table}})))
    {
      write_line($table, $dml, $count_hash->{$table}->{$dml});
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
      write_line($time_printable, $count_hash->{$time});
    }
    elsif ($group_by eq sort_csv("time,table") || $group_by eq sort_csv("time,statement"))
    {
      foreach my $element (sort(keys(%{$count_hash->{$time}})))
      {
        write_line($time_printable, $element, $count_hash->{$time}->{$element});
      }
    }
    elsif ($group_by eq "all" || $group_by eq sort_csv("time,table,statement"))
    {
      foreach my $table (sort(keys(%{$count_hash->{$time}})))
      {
        foreach my $dml (sort(keys(%{$count_hash->{$time}->{$table}})))
        {
          write_line($time_printable, $table, $dml, $count_hash->{$time}->{$table}->{$dml});
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
  my ($cell)= @_;
  my ($parse, $format);

  if ($cell eq "h" || $cell eq "hour" || $cell eq "1h")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}):\d{2}:\d{2}/;
    $format= "%s:00";
  }
  elsif ($cell eq "m" || $cell eq "minute" || $cell eq "1m")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}):\d{2}/;
    $format= "%s";
  }
  elsif ($cell eq "10m")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{1})\d{1}:\d{2}/;
    $format= "%s0";
  }
  elsif ($cell eq "10s")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}:\d{1})\d{1}/;
    $format= "%s0";
  }
  elsif ($cell eq "s" || $cell eq "second" || $cell eq "1s")
  {
    $parse = qr/^#(\d{2}\d{2}\d{2}\s+\d{1,2}:\d{2}:\d{2})/;
    $format= "%s";
  }
  else
  {
    $parse = undef;
    $format= undef;
  }

  return ($parse, $format);
}


sub write_line
{
  my (@args)= @_;
  my $seperator= $output eq "tsv" ? "\t" : $output eq "csv" ? "," : "\n";

  printf("%s\n", join($seperator, @args));
}


sub sort_csv
{
  my ($csv)= @_;

  return join(",", sort(split(/,/, $csv)));
}


sub usage
{
  my ($msg)= @_;

  print << "EOS";
$0 is aggregator of mysqlbinlog's output. $msg

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
                          "s", "second", "1s",
                          "10s",
                          "m", "minute", "1m",
                          "10m", 
                          "h", "hour", "1h"
  --group-by=string     Part of aggregation. [default: time]
                          "time", "table", "statement",
                          "time,table", "time,statement", "table,statement",
                          "all", "time,table,statement" (same as "all")
  --save                Save scrpit's stdin(mysqlbinlog's stdout) into $save_file
  --output=string       Output type. [default: tsv]
                          "tsv", "csv"
  --usage, --help, -h   Print this message.
EOS
  exit 0;
}
