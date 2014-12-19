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

function usage
{
  echo "$0 <version_string>" >&2
  exit 1
}

if [ "$#" -ne 1 ] ; then
  usage
else
  VERSION="$1"
fi

MIRROR_URL="http://vault.centos.org/${VERSION}/os/x86_64/"
MIRROR_URL_UPDATES="http://vault.centos.org/${VERSION}/updates/x86_64/"

febootstrap -i bash -i coreutils -i tar -i bzip2 -i gzip -i vim-minimal -i wget -i patch -i diffutils -i iproute -i yum centos centos${VERSION}  $MIRROR_URL -u $MIRROR_URL_UPDATES
tar --numeric-owner -cp -C centos${VERSION} . | docker import -
docker images

exit 0
