#!/bin/bash

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

function usage
{
  local msg="$1"
  cat << EOF
$0 <workdir> [<mysqlbinlog's options>]
  <workdir>                Mandatory, path to directory which this script stores binlog.
  <mysqlbinlog's options>  Optionally, options like "--user", "--password", "--host".

$msg
EOF
  exit 0
}

function logme
{
  local msg="$1"
  : Improve me at your way.
  echo $msg
}

### Add path if mysqlbinlog isn't default PATH.
PATH=$PATH

### Fill MYSQL_* environment if you don't want to pass connect options.
export MYSQL_PWD=""
export MYSQL_HOST=""
export MYSQL_TCP_PORT=""
export MYSQL_TEST_LOGIN_FILE=""
export MYSQL_UNIX_PORT=""

workdir="$1"
shift
args="$@"

[ -z "$workdir" ] && usage "Directory must be specified"
[ -w "$workdir" -a -x "$workdir" ] || mkdir -p "$workdir" || usage "Permission denied(must have +rwx)"

exec=$(which mysqlbinlog 2> /dev/null)
if [ -z "$exec" ] ; then
  usage "Can't find mysqlbinlog in PATH"
fi

mysqlbinlog --help 2> /dev/null | grep stop-never > /dev/null
if [ "$?" -ne 0 ] ; then
  usage "$exec doesn't support --stop-never option. This introduced by MySQL 5.6.0"
fi

cd $workdir
trap 'kill $(jobs -p) ; exit 0' 1 2 3 15

while true ; do
  latest=$(ls *.[0-9]*[0-9][0-9] 2> /dev/null | tail -1)
  grant=$(mysql $args -sse "SHOW GRANTS")
  if [ -z "$grant" ] ; then
    usage "mysqlbinlog's option is something wrong (or MySQL server downs)"
  else
    echo $grant | egrep "REPLICATION SLAVE|ALL PRIVILEGES " > /dev/null
    if [ "$?" -ne 0 ] ; then
      usage "Given user doesn't have REPLICATION SLAVE privilege"
    fi
  fi
  
  if [ -z "$latest" ] ; then
    latest=$(mysql $args -sse "SHOW BINARY LOGS" | head -1 | awk '{print $1}' 2> /dev/null)
  
    if [ -z "$latest" ] ; then
      usage "SHOW BINARY LOGS(auto-detection of binlog which $0 should start) failed. Need REPLICATION CLIENT privilege"
    fi
  fi
  
  logme "Starting to receive since $latest"
  mysqlbinlog -R --raw --stop-never $args $latest &
  wait
  logme "mysqlbinlog stop detected. Restarting 10 seconds over."
  sleep 10
done

