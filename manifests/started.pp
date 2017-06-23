# Copyright (C) 2017 Collaboration of KPN and Splendid Data
#
# This file is part of puppet_pure_postgres.
#
# puppet_pure_barman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# puppet_pure_postgres is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with puppet_pure_postgres.  If not, see <http://www.gnu.org/licenses/>.

# == Class: pure_postgres::started
#
# Wait until postgres is started

define pure_postgres::started
(
  $retries     = 5,
  $sleep       = 1,
)
{

  $cmd = shellquote( 'bash', '-c', "for ((i=0;i<${retries};i++)); do 
                        echo 'select datname from pg_database' | psql -q -t 2>&1 && break; sleep ${sleep}; done" )

  exec { $title:
    refreshonly => $refreshonly,
    user        => $pure_postgres::params::postgres_user,
    command     => $cmd,
    onlyif      => "test -f '${pure_postgres::params::pg_pid_file}'",
    path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd         => $pure_postgres::params::pg_bin_dir,
    loglevel    => 'debug',
  }

}

