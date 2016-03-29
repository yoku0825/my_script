package MeCab;
 
use strict;
use warnings;
use utf8;
use base qw/Class::Accessor/;
use Carp;
 
use Text::MeCab;
use Encode;
use Unicode::Japanese;
 
 
sub new
{
  my ($class, $config)= @_;
 
  my $self= {mecab => Text::MeCab->new({dicdir => $config->{dicdir}})};
  bless $self => $class;
  $class->mk_accessors(keys(%$self));
  return $self;
}
 
 
sub normalize
{
  my ($self, @string)= @_;
  my @ret;
  map { push(@ret, $_->{surface}); } @{$self->raw_loop("normalize", @string)};
  return join("", @ret);
}
 
 
sub parse
{
  my ($self, @string)= @_;
  my @ret;
  map { push(@ret, $_->{surface}); } @{$self->raw_loop("parse", @string)};
  return \@ret;
}
 
 
sub raw_parse
{
  my ($self, @string)= @_;
  return $self->raw_loop("parse", @string);
}
 
 
sub raw_loop
{
  my ($self, $type, @string)= @_;
  my @ret;
 
  foreach my $str (@string)
  {
    next unless $str;
 
    if ($type eq "normalize")
    {
      $str = Unicode::Japanese->new($str)->z2h->h2zKana->get;
      $str =~ tr/a-z/A-Z/;
    }
 
    for (my $node= $self->mecab->parse($str); $node; $node= $node->next)
    {
      if (my $ret= $self->fix_node($node))
      {
        next if $ret->{type} eq "記号";

        ### remove token which has only one character of Hiragana or Katakana.
        next if $ret->{surface} =~ /^[あ-んア-ン]$/;
 
        unless ($type eq "normalize")
        { 
          if ($ret->{read})
          {
            ### read is nullable
          }
          next if $ret->{type} eq "数詞";
          next if $ret->{type_detail1} eq "数";
          next if $ret->{type} eq "感動詞";
          next if $ret->{conjugate1} eq "特殊・デス";
          next if $ret->{surface} eq "ー";
        }
        push(@ret, $ret);
      }
    }
  }
  return \@ret;
}
 
 
sub fix_node
{
  my ($class, $node)= @_;
 
  return 0 if $node->stat =~ /^[23]$/;
  return 0 unless $node->surface;
 
  my $feature= decode("utf8", $node->feature);
  my $surface= decode("utf8", $node->surface);
  my @ret = split(/,/, $feature);
 
  return {type         => $ret[0], type_detail1 => $ret[1],
          type_detail2 => $ret[2], type_detail3 => $ret[3],
          conjugate1   => $ret[4], conjugate2   => $ret[5],
          origin       => $ret[6], read         => $ret[7],
          pronounse    => $ret[8], surface      => $surface};
}
 
 
return 1;



