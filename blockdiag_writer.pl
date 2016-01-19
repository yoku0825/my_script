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

my $block= BlockDiag->new;

foreach (qw/a b c ac d cd/)
{
  $block->node($_, {param => {color => "blue", textcolor => "white"}});
}

$block->edge({start => "ac", end => "d", param => {color => "red"}});
$block->nodes->{a}->add_edge("zzzz", {color => "rrr"});

my $n= $block->node("n", {color => "green"});
$n->add_edge("bb");

my $dq= $block->node("dddq2");
my $group= $block->group("mygroup", {member => [$n, $dq]});

$group->add("q");
$group->param({label => "test_group"});

$block->print;

exit 1;





package BlockDiag;

use strict;
use warnings;
use utf8;
use base qw/Class::Accessor/;
use Carp;

sub new
{
  my ($class)= @_;
  my $self= {nodes  => {},
             edges  => {},
             groups => {},
            };
  bless $self => $class;
  $class->mk_accessors(keys(%$self));

  return $self;
}


sub node
{
  my ($self, $id, $param, $add_param)= @_;

  croak("Node $id is already defined") if defined($self->nodes->{$id});
  $self->nodes->{$id}= BlockDiag::Node->new($id, $param, $add_param);

  return $self->nodes->{$id};
}


sub edge
{
  my ($self, $opt)= @_;
  my $start= $opt->{start};
  my $end  = $opt->{end};

  croak("Edge between $start and $end is already defined.") if defined($self->edges->{$start => $end});
  $self->node($start) unless ref($self->nodes->{$start}) eq "BlockDiag::Node";
  $self->node($end)   unless ref($self->nodes->{$end}) eq "BlockDiag::Node";

  $self->edges->{$start => $end}= BlockDiag::Edge->new($opt);

  return $self->edges->{$start => $end};
}


sub group
{
  my ($self, $group, $opt)= @_;

  croak("Group $group is already defined.") if defined($self->groups->{$group});
  $self->groups->{$group}= BlockDiag::Group->new($group, $opt);

  return $self->groups->{$group};
}


sub print
{
  my ($self)= @_;

  ### Header
  printf("blockdiag\n{\n");

  ### Nodes
  print("  //Nodes\n");
  foreach (sort(keys(%{$self->nodes})))
  {
    my $node= $self->nodes->{$_};
    _print_node($node);
  }

  print "\n";

  ### Edges
  print("  //Edges\n");
  foreach (sort(keys(%{$self->edges})))
  {
    my $edge= $self->edges->{$_};
    _print_edge($edge);
  }

  print "\n";

  ### Groups
  print("  //Groups\n");
  foreach (sort(keys(%{$self->groups})))
  {
    my $group= $self->groups->{$_};

    printf("  group %s\n  {\n", $group->group);

    _print_group_param($group) if $group->param;
    _print_member($group);

    printf("  }\n");
  }

  print("}\n");
}

sub _print_node
{
  my ($node)= @_;

  printf("  %s", $node->id);
  _print_param($node);
  print(";\n");
} 


sub _print_edge
{
  my ($edge)= @_;

  printf("  %s -> %s", $edge->start, $edge->end);
  _print_param($edge);
  print(";\n");
} 


sub _print_member
{
  my ($group) =@_;

  foreach my $member (@{$group->member})
  {
    if (ref($member) eq "BlockDiag::Node")
    {
      print("  ");
      _print_node($member);
    }
    elsif (ref($member) eq "BlockDiag::Edge")
    {
      print("  ");
      _print_edge($member);
    }
  }
}
 

sub _print_group_param
{
  my ($group)= @_;

  foreach (sort(keys(%{$group->param})))
  {
    printf(qq{    %s = "%s";\n}, $_, $group->param->{$_});
  }
} 




sub _print_param
{
  my ($element)= @_;
  my @ret;

  if ($element->param)
  {
    map { push(@ret, sprintf(qq{%s = "%s"}, $_, $element->param->{$_})); } (sort(keys(%{$element->param})));
  }

  if ($element->add_param)
  {
    map { push(@ret, sprintf("%s", $_)); } (sort(@{$element->add_param})); 
  }

  if (@ret)
  {
    print(" [");
    print(join(", ", @ret));
    print("]");
  }
}
 


package BlockDiag::Node;

use strict;
use warnings;
use utf8;
use base qw/Class::Accessor/;
use Carp;

sub new
{
  my ($class, $id, $opt)= @_;
  my $self= {id        => $id,
             param     => $opt->{param},
             add_param => $opt->{add_param},
            };
  bless $self => $class;
  $class->mk_accessors(keys(%$self));

  return $self;
}


sub add_edge
{
  my ($self, $to, $opt)= @_;
  $block->edge({start => $self->id, end => $to, $opt ? %$opt : undef});
}


package BlockDiag::Edge;

use strict;
use warnings;
use utf8;
use base qw/Class::Accessor/;
use Carp;

sub new
{
  my ($class, $opt)= @_;
  my $self= {start     => $opt->{start},
             end       => $opt->{end},
             param     => $opt->{param},
             add_param => $opt->{add_param},
            };
  bless $self => $class;
  $class->mk_accessors(keys(%$self));

  return $self;
}


package BlockDiag::Group;

use strict;
use warnings;
use utf8;
use base qw/Class::Accessor/;
use Carp;

sub new
{
  my ($class, $group, $opt)= @_;
  my $self= {group     => $group,
             member    => $opt->{member},
             param     => $opt->{param},
            };
  bless $self => $class;
  $class->mk_accessors(keys(%$self));

  return $self;
}


sub add
{
  my ($self, $member)= @_;

  $member= $block->node($member) if (ref($member) ne "BlockDiag::Node" && ref($member) ne "BlockDiag::Edge");

  return 0 if grep { $member eq $_ } (@{$self->member});
  push(@{$self->member}, $member);
}
