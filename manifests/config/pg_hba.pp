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

# == Class: pure_postgres::config::pg_hba
#
# Change pg_hba on a postgrespure database server
define pure_postgres::config::pg_hba
(
  $database        = undef,
  $pg_hba_file     = $pure_postgres::config::pg_hba_conf,
  $method          = undef,
  $netmask         = '',
  $state           = 'present',
  $source          = undef,
  $connection_type = undef,
  $user            = undef,

)
{

  $cmd = shellquote( "${pure_postgres::pg_bin_dir}/modify_pg_hba.py", '-c', '-d', $database, '-f', $pg_hba_file, '-m', $method,
                      '-n', $netmask, '--state', $state, '-s', $source, '-t', $connection_type, '-u', $user , '--reload')

  exec { "exec ${cmd}":
    user    => $pure_postgres::config::postgres_user,
    command => $cmd,
    require => File["${pure_postgres::params::pg_bin_dir}/modify_pg_hba.py"],
    unless  => "${cmd} --check",
  }

}

