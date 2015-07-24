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
declare directory_for_setup="/tmp/setup"
declare -a files_for_salvage=("/root/.bash_history")
declare -a repositories_for_pull=("yoku0825/here" \
                                  "yoku0825/cent66:init" \
                                  "yoku0825/mysql_fabric_aware" \
                                  "yoku0825/private:kibana4")
declare -a repositories_for_push=("${repositories_for_pull[@]}")


function enter_into_container
{
  local container_name="$1"

  target=$(docker inspect --format "{{.State.Pid}}" "$container_name")
  sudo nsenter --target $target --mount --uts --ipc --net --pid bash
}

function arbitrate_container_name
{
  local container_name="$1"
  local old_container_name="$2"
  container_already_exists=$(\docker ps -a | awk '$NF == "'$container_name'"')

  if [ ! -z "$container_already_exists" ] ; then
    arbitrate_container_name ${container_name}1 ${container_name}
  fi

  if [ ! -z "$old_container_name" ] ; then
    \docker rename $old_container_name $container_name
  fi
}

function newest_running_container_id
{
  echo $(\docker ps | grep -v "^CONTAINER ID" | head -1 | awk '{print $1}')
}

function newest_container_id
{
  echo $(\docker ps -a | grep -v "^CONTAINER ID" | head -1 | awk '{print $1}')
}

function pull_all_repositories
{
  for f in ${repositories_for_pull[*]} ; do
    \docker pull "$f"
  done
}

function push_all_repositories
{
  for f in ${repositories_for_push[*]} ; do
    \docker push "$f"
  done
}

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
  
    #salvage_from_container $container_id
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
    \docker stop $container_id
  done
}

function display_one_information
{
  container_id="$1"
  \docker inspect -f "{{.Name}}, {{.Config.Hostname}}, {{.NetworkSettings.IPAddress}}, {{.Config.Entrypoint}}, {{.Config.Cmd}}, {{.NetworkSettings.Ports}}" $container_id | sed 's|^/||'
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

function connect_via_ssh
{
  container_id="$1"

  ssh "$(\docker inspect -f "{{.NetworkSettings.IPAddress}}" "$container_id")"
}

function connect_via_scp
{
  source_file="$1"
  dst_container="$2"

  scp $source_file $(\docker inspect -f "{{.NetworkSettings.IPAddress}}" "$container_id"):~/
}

function pull_dockerfile
{
  image_id="$1"

  \docker run --name pull_dockerfile "$1" tar cf /tmp/setup.tar -C $directory_for_setup .
  \docker cp pull_dockerfile:/tmp/setup.tar $directory_for_copy/$image_id/
  \docker rm pull_dockerfile
  echo "outputted: $directory_for_copy/$image_id/setup.tar"
}

function usage
{
  name=$(basename $0)
  cat << EOF
$name is wrapper script for docker.

Implementated subcommands:
  "$name a" is same as "$name attach", see also extended subcommand of "attach".
  "$name bash" is same as "docker run -it bash".
  "$name enter" executs nsenter like docker_enter.
  "$name file" is picking image's $directory_for_setup.
  "$name here" is same as "docker run -d yoku0825/here".
  "$name im" is same as "docker images".
  "$name logs" is same as "docker logs -t -f --tail=10".
  "$name logs" with no argument behave to be gave container_id which is first one in docker ps.
  "$name scp" is copying via scp using container_id, first arg is file which will be copy, second arg is container_id.
  "$name show" is displaying container's name, hostname, IP address, and executing.
  "$name ssh" is connecting via ssh using container_id.
  "$name ssh" with no argument behave to be gave container_id which is first one in docker ps.
  "$name usage" is showing this message.

Extended subcommands:
  "$name attach" is same as "docker start && docker attach".
  "$name attach" with no argument behave to be gave container_id which is first one in docker ps -a.
  "$name build" if you don't give --tag option, adding "--tag work" automatically.
  "$name pull" will pull repositories listed in \$repositories_for_pull, if you don't give any argument.
  "$name push" will push repositories listed in \$repositories_for_push, if you don't give any argument.
  "$name ps" adds "-a" option implecitly.
  "$name rm" has three extends,
    Stopping container, if it is still running(danger).
    Removing all containers, if you don't give any argument.
    Copying \$files_for_salvage from container, before removing container.
  "$name rmi" will remove all images without tag, if you don't give any argument.
  "$name run" with -d option, displaying container's information which is same as "$name show".
  "$name run" is always treated with --privileged.
  "$name stop" will stop all containers, if you don't give any argument.

These are usage of $name, type "docker help" if you need docker's usage.
EOF
}


command="$1"
shift

case "$command" in
  "a"|"attach")
    if [ -z "$*" ] ; then
      container_id=$(newest_container_id)
    else
      container_id="$1"
    fi
    start_and_attach $container_id
    ;;
  "bash")
    container_id="$1"
    arbitrate_container_name "bash"
    \docker run -it --privileged --name bash $container_id bash
    ;;
  "build")
    if [[ ! "$*" =~ --tag ]] ; then
      \docker build --tag work $*
    else
      \docker build $*
    fi
    ;;
  "enter")
    if [ -z "$*" ] ; then
      container_id=$(newest_running_container_id)
    else
      container_id="$1"
    fi
    enter_into_container $container_id
    ;;
  "file")
    pull_dockerfile $1
    ;;
  "here")
    arbitrate_container_name "here"
    container_id=$(\docker run -d --privileged --name here yoku0825/here)
    display_one_information $container_id
    ;;
  "im")
    \docker images $*
    ;;
  "logs")
    if [ -z "$*" ] ; then
      container_id=$(newest_container_id)
    else
      container_id="$1"
    fi
    \docker logs -t -f --tail=10 $container_id
    ;;
  "pull")
    if [ -z "$*" ] ; then
      pull_all_repositories
    else
      \docker pull $*
    fi
    ;;
  "push")
    if [ -z "$*" ] ; then
      push_all_repositories
    else
      \docker push $*
    fi
    ;;
  "ps")
    \docker ps -a $*
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
    if [[ ! "$*" =~ "--name " ]] ; then
      container_name=$(echo ${@:$#} | awk -F"[/:]" '{print $3 ? $3 : $2 ? $2 : $1}')
      arbitrate_container_name $container_name
      container_name="--name $container_name"
    fi

    if [[ "$*" =~ "-d " ]] ; then
      container_id=$(\docker run --privileged $container_name $*)
      display_one_information $container_id
    else
      \docker run --privileged $container_name $*
    fi
    ;;
  "scp")
    source_file="$1"
    dst_container="$2"
    if [ -z "$dst_container" ] ; then
      container_id=$(newest_running_container_id)
    else
      container_id="$dst_container"
    fi
    connect_via_scp $source_file $dst_container
    ;;
  "show")
    display_all_information
    ;;
  "ssh")
    if [ -z "$*" ] ; then
      container_id=$(newest_running_container_id)
    else
      container_id="$1"
    fi
    connect_via_ssh $container_id
    ;;
  "stop")
    if [ -z "$*" ] ; then
      stop_all_containers
    else
      \docker stop $*
    fi
    ;;
  "usage")
    usage
    ;;
  *)
    \docker $command $*
    ;;
esac


