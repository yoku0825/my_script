#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use XML::Simple;
use HTTP::Tiny;
use Time::Piece qw{localtime};
use Time::Seconds;

my $image_name="yyoshiki41/radigo";
my @keyword= qw{ radio_title_which_you_want_download };

create_list();
my $hash;
eval
{
  no strict;
  no warnings "once";
  require "list.txt";
  $hash= $VAR1;
};

my $term= localtime() - 3 * ONE_HOUR;

foreach my $prog (@$hash)
{
  if ($prog->{from} < $term->strftime("%Y%m%d%H%M%S"))
  {
    my ($command, $origfile, $newfile)= make_docker_run_command($prog);
    if (-e $newfile)
    {
      ### already completed
      next;
    }
    else
    {
      if (-e $origfile)
      {
        ### downloaded but maybe corrupt.
        unlink($origfile);
      }
      print $command, "\n";

      system($command);
      rename($origfile, $newfile);
    }
  }
}

sub make_docker_run_command
{
  my ($prog)= @_;

  my $command= sprintf("docker run -it -v %s/output:/output %s rec -id=%s -start=%s",
                       $ENV{PWD}, $image_name, $prog->{station}, $prog->{from});
  my $origfile= sprintf("output/%s-%s.aac", $prog->{from}, $prog->{station});
  my $newfile = sprintf("output/%s_%s.aac", $prog->{title}, substr($prog->{from}, 0, 8));

  return ($command, $origfile, $newfile);
}

sub create_list
{
  open(my $fh, ">", "list.txt");
  binmode $fh, ":utf8";
  print($fh "\$VAR1=[\n");

  foreach my $station (qw{TBS QRR LFR RN1 RN2 INT FMT FMJ JORF BAYFM78 NACK5 YFM HOUSOU-DAIGAKU JOAK JOAB JOAK-FM})
  {
    my $filename= create_cache($station);
    my $program = read_cache($filename);
    
    foreach (@$program)
    {
      foreach (@{$_->{prog}})
      {
        my $title= $_->{title};
        if (grep { $title =~ $_ } @keyword)
        {
          printf($fh "{ from => '%d', title => '%s', station => '%s', }, \n",
                     $_->{ft}, $_->{title}, $station);
        }
      }
    }
  }
  print($fh "];\n");
  close($fh);
}

sub create_cache
{
  my ($station)= @_;

  my $now = localtime;
  my $filename= sprintf("cache/%s.xml", $station);
  my @stat= stat($filename);

  if (@stat && $stat[9] + ONE_DAY > $now->epoch)
  {
    ### Read from cache.
  }
  else
  {
    my $http= HTTP::Tiny->new;
    open(my $fh, ">", $filename);
    my $url= sprintf("http://radiko.jp/v3/program/station/weekly/%s.xml", $station);
    print($fh $http->get($url)->{content});
    close($fh);
  }

  return $filename;
}

sub read_cache
{
  my ($filename)= @_;

  open(my $fh, "<", $filename);
  my @buff= <$fh>;
  close($fh);

  my $xml= XMLin(join("\n", @buff), keyattr => {});
  my $program= $xml->{stations}->{station}->{progs};
 
  return $program;
}
