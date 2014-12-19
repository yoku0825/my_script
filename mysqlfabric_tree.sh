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

next_is_data=0
mysqlfabric group lookup_groups | while read group ; do
  if [[ "$next_is_data" = 1 ]] ; then
    if [[ "$group" =~ ^$ ]] ; then
      break
    else
      group_name=$(echo $group | awk '{print $1}')
      echo -e "\033[31;1m$group_name\033[0m"
      next_is_data_in=0
      mysqlfabric group lookup_servers $group_name | while read server ; do
        if  [[ "$next_is_data_in" = 1 ]] ; then
          if [[ "$server" =~ ^$ ]] ; then
            break
          else
            echo -e "\t$server"
          fi
        elif [[ "$server" =~ ------ ]] ; then
          next_is_data_in=1
        fi
      done
    fi
  elif [[ "$group" =~ ------ ]] ; then
    next_is_data=1
  fi
done

