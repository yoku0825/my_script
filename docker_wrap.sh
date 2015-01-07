#!/bin/bash

########################################################################
# Copyright (C) 2015  yoku0825
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

declare directory_for_copy="/tmp/docker"
declare -a files_for_salvage=("/root/.bash_history")

function salvage_from_container
{
  container_id="$1"

  for i in ${files_for_salvage[*]} ; do
    \docker cp $container_id:$i $directory_for_copy/$container_id
  done

  echo "salvaged: $directory_for_copy/$container_id"
}

function remove_one_container
{
  while [ ! -z "$*" ] ; do
    container_id="$1"
    shift

    if [ "$(\docker inspect -f "{{.State.Running}}" "$container_id")" = "true" ] ; then
      \docker stop $container_id
    fi
  
    salvage_from_container $container_id
    \docker rm $container_id
  done
}

function remove_all_containers
{
  \docker ps -a | grep -v "^CONTAINER ID" | awk '{print $1}' | while read container_id ; do
    remove_one_container $container_id
  done
}

function remove_one_image
{
  while [ ! -z "$*" ] ; do
    image_id="$1"
    shift
  
    \docker ps -a | awk '$2 == "'$image_id'" {print $1}' | while read container_id ; do
      remove_one_container $container_id
    done
  
    \docker rmi $image_id
  done
}

function remove_all_images
{
  \docker images | awk '$1 == "<none>" && $2 == "<none>" {print $3}' | while read image_id ; do
    remove_one_image $image_id
  done
}

function stop_all_containers
{
  \docker ps | grep -v "^CONTAINER ID" | awk '{print $1}' | while read container_id ; do
    \dcoker stop $container_id
  done
}

function display_one_information
{
  container_id="$1"
  \docker inspect -f "{{.Name}}, {{.Config.Hostname}}, {{.NetworkSettings.IPAddress}}, {{.Config.Cmd}}" $container_id | sed 's|^/||'
}

function display_all_information
{
  \docker ps | grep -v "^CONTAINER ID" | awk '{print $1}' | while read container_id ; do
    display_one_information $container_id
  done
}

function start_and_attach
{
  container_id="$1"

  if [ "$(\docker inspect -f "{{.State.Running}}" "$container_id")" = "false" ] ; then
    \docker start $container_id
  fi

  \docker attach $container_id
}

function pull_dockerfile
{
  image_id="$1"

  \docker run --name pull_dockerfile "$1" tar cf /root/setup.tar setup -C /root
  \docker cp pull_dockerfile:/root/setup.tar $directory_for_copy/$image_id/
  \docker rm pull_dockerfile
  echo "outputted: $directory_for_copy/$image_id/setup.tar"
}


command="$1"
shift

case "$command" in
  "attach")
    container_id="$1"
    start_and_attach $1
    ;;
  "bash")
    container_id="$1"
    \docker run -it $container_id bash
    ;;
  "build")
    if [[ ! "$*" =~ --tag ]] ; then
      \docker build --tag work $*
    else
      \docker build $*
    fi
    ;;
  "file")
    pull_dockerfile $1
    ;;
  "rm")
    if [ -z "$*" ] ; then
      remove_all_containers
    else
      remove_one_container $*
    fi
    ;;
  "rmi")
    if [ -z "$*" ] ; then
      remove_all_images
    else
      remove_one_image $*
    fi
    ;;
  "run")
    if [[ "$*" =~ "-d " ]] ; then
      container_id=$(docker run $*)
      display_one_information $container_id
    else
      docker run $*
    fi
    ;;
  "show")
    display_all_information
    ;;
  "stop")
    if [ -z "$*" ] ; then
      stop_all_containers
    else
      \docker stop $*
    fi
    ;;
  *)
    \docker $command $*
    ;;
esac

