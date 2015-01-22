#!/bin/bash

########################################################################
# Copyright (C) 2014, 2015  yoku0825
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


function usage
{
  echo "$0 {start|clear} {group_name1 group_name2 ..}" >&2
  exit 2
}

function start
{
  docker pull yoku0825/mysql_fabric_aware
  mysqlfabric manage setup
  mysqlfabric manage start --daemonize

  for buf in $* ; do
    s=$(echo $buf | awk -F, '{print $1}')
    n=$(echo $buf | awk -F, '{print $2 ? $2 : 1}')

    mysqlfabric group create $s

    for n in $(seq 1 $n) ; do
      id="${s}_${n}"
      docker run -d -h $id --name $id yoku0825/mysql_fabric_aware
      ipaddr=$(docker inspect -f {{.NetworkSettings.IPAddress}} $id)
      sleep 10
      mysqlfabric group add $s $ipaddr
    done

    mysqlfabric group activate $s
    mysqlfabric group promote $s
  done
}

function clear
{
  mysqlfabric manage stop
  docker stop $(docker ps -a | grep "mysql_fabric_aware" | awk '{print $1}')
  docker rm   $(docker ps -a | grep "mysql_fabric_aware" | awk '{print $1}')
  mysqlfabric manage teardown
}

if [ "$#" -lt 1 ] ; then
  usage
else
  command="$1"
  shift
fi

if [ "$command" = "start" ] ; then
  if [ $# -lt 1 ] ; then
    echo "Group name is not specified." >&2
    usage
  else
    start $*
  fi
elif [ "$command" = "clear" ] ; then
  clear
else
  echo "Command $command is unsupported." >&2
  usage
fi

exit 0
