#!/bin/bash

########################################################################
# Copyright (C) 2016, 2018  yoku0825
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

command="$1"
shift

case "$command" in
  "diff")
    git diff --color-words --ignore-all-space $*
    ;;
  "fetch")
    if [ -z "$*" ] ; then
      git fetch --prune --all
    else
      git fetch --prune $*
    fi
    ;;
  "log")
    git log --name-only $*
    ;;
  "pr")
    pr_num="$1"
    git fetch origin pull/${pr_num}/head:pull_${pr_num}
    git checkout pull_${pr_num}
    ;;
  "tree")
    git log --graph --all --format="%x09%C(cyan bold)%an%Creset%x09%C(yellow)%h%Creset %C(magenta reverse)%d%Creset %s"
    ;;
  *)
    git $command $*
    ;;
esac


