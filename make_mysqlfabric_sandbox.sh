#!/bin/bash

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


function start
{
  docker pull yoku0825/cent66:fabric_aware_5622
  for s in $* ; do
    mysqlfabric group create $s
    docker run -d -h $s --name $s yoku0825/cent66:fabric_aware_5622
    ipaddr=$(docker inspect -f {{.NetworkSettings.IPAddress}} $s)
    sleep 5
    mysqlfabric group add $s $ipaddr
    mysqlfabric activate $s
    mysqlfabric group promote $s
  done
}

function clear
{
  mysqlfabric manage stop
  docker stop $(docker ps -a | grep "fabric_aware_5622" | awk '{print $1}')
  docker rm   $(docker ps -a | grep "fabric_aware_5622" | awk '{print $1}')
  mysqlfabric manage teardown
  mysqlfabric manage setup
  mysqlfabric manage start --daemonize
}

command="$1"
shift

if [ "$command" = "start" ] ; then
  if [ $# -lt 1 ] ; then
    echo "Syntax Error." >&2
    exit 1
  else
    start $*
  fi
elif [ "$command" = "clear" ] ; then
  clear
else
  echo "Command $command is unsupported." >&2
  exit 2
fi

exit 0
