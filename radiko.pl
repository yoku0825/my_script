#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode;

use XML::Simple;
use HTTP::Tiny;
use Time::Piece qw{localtime};
use Time::Seconds;
use WebService::Dropbox;
use Config::Pit qw{pit_get};

my @keyword= qw{ radio_title_which_you_want_download };
binmode STDOUT, ":utf8";

my $image_name="yyoshiki41/radigo:v0.11.0";
my $verbose= 0;

create_list();
my $hash;
eval
{
  no strict;
  no warnings "once";
  require "cache/list.txt";
  $hash= $VAR1;
};

my $term= localtime() - 3 * ONE_HOUR;

my $config= pit_get("dropbox");
my $dropbox= WebService::Dropbox->new($config);
$dropbox->access_token($config->{access_token});

foreach my $prog (@$hash)
{
  if ($prog->{from} < $term->strftime("%Y%m%d%H%M%S"))
  {
    my ($command, $origfile, $newfile)= make_docker_run_command($prog);
    if (!(-e $newfile))
    {
      if (-e $origfile)
      {
        ### downloaded but maybe corrupt.
        unlink($origfile);
      }
      print $command, "\n";

      system($command);
      rename($origfile, $newfile);
$|=1;
      my ($basename)= $newfile =~ qr|/([^/]+)$|;
      $basename= decode("utf-8", $basename);
      print $basename;


      open(my $fh, "<", $newfile);
      $dropbox->upload_session("/radio/$basename", $fh) || $dropbox->error;
      close($fh);
    }
  }
}

sub make_docker_run_command
{
  my ($prog)= @_;

  my $command= sprintf("docker run --rm -v %s/output:/output %s rec -id=%s -start=%s -output=mp3",
                       $ENV{PWD}, $image_name, $prog->{station}, $prog->{from});
  my $origfile= sprintf("%s-%s.mp3", $prog->{from}, $prog->{station});
  my $newfile = sprintf("%s_%s.mp3", substr($prog->{from}, 0, 8), $prog->{title});

  ### if $newfile has "/", 
  $newfile =~ s|/|_|g;

  return ($command, sprintf("output/%s", $origfile), sprintf("output/%s", $newfile));
}

sub create_list
{
  my $filename= "cache/list.txt";
  #return 0 if !(one_day_ago($filename));
 
  open(my $fh, ">", $filename);
  binmode $fh, ":utf8";
  print($fh "\$VAR1=[\n");

  foreach my $station (qw{TBS QRR LFR RN1 RN2 INT FMT FMJ JORF BAYFM78 NACK5 YFM})
  {
    print $station, "\n" if $verbose;
    my $filename= create_cache($station) || die $!;
    my $program = read_cache($filename) || die $!;
    
    foreach (@$program)
    {
      printf("%s: %d progs\n", $filename, scalar(@{$_->{prog}})) if $verbose;
      foreach (@{$_->{prog}})
      {
        my $title= $_->{title};
        print $title, "\n" if $verbose;
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

  my $filename= sprintf("cache/%s.xml", $station);
  return $filename if !(one_day_ago($filename));

  my $http= HTTP::Tiny->new;
  open(my $fh, ">", $filename);
  my $url= sprintf("http://radiko.jp/v3/program/station/weekly/%s.xml", $station);

  my $ret= $http->get($url);
  if ($ret->{success})
  {
    printf("GET %s succeeded\n", $url) if $verbose;
    print($fh $http->get($url)->{content});
  }
  else
  {
    print(STDERR "$url failed");
  }

  close($fh);

  return $filename;
}

sub read_cache
{
  my ($filename)= @_;

  open(my $fh, "<", $filename);
  my @buff= <$fh>;
  close($fh);

  printf("Start to read %s\n", $filename) if $verbose;
  my $xml= XMLin(join("\n", @buff), keyattr => {});
  my $program= $xml->{stations}->{station}->{progs};
 
  return $program;
}

sub one_day_ago
{
  my ($filename)= @_;
  my $now = localtime;
  my @stat= stat($filename);

  if (@stat && $stat[9] + ONE_DAY > $now->epoch)
  {
    ### Read from cache.
    return 0;
  }
  return 1;
}
