/* Copyright (c) 2016, yoku0825. All rights reserved.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; version 2 of the License.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

/* gcc -I/path/to/mysql/include -L/path/to/mysql/lib -lmysqlclient */

#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>

#define PING_USER "mysql_ping"
#define PING_PASSWORD ""
#define TIMEOUT 2

int main(int argc, char **argv)
{
  if (argc != 3)
    return 255;

  char* host   = argv[1];
  int   port   = atoi(argv[2]);
  uint  timeout= TIMEOUT;

  MYSQL mysql;
  mysql_init(&mysql);
  mysql_options(&mysql, MYSQL_OPT_CONNECT_TIMEOUT, (char*) &timeout);
  mysql_options(&mysql, MYSQL_OPT_READ_TIMEOUT, (char*) &timeout);
  mysql_options(&mysql, MYSQL_OPT_WRITE_TIMEOUT, (char*) &timeout);

  if (mysql_real_connect(&mysql, host, PING_USER, PING_PASSWORD, NULL, port, NULL, 0))
  {
    mysql_close(&mysql);
    return 0;
  }
  else if (mysql_errno(&mysql) < 2000)
    return 0;
  else
    return 1;
}
