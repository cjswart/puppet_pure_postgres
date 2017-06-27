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

# == Deinition: pure_postgres::sql::run_sql
define pure_postgres::sql::run_sql (
  $sql,
  $unless = undef,
  $user   = $pure_postgres::params::postgres_user,
  $db     = 'postgres',
)
{

  assert_private('run_sql is for internal pure_postgres purposes only')

  if $db !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${db}.")
  }

  $run_cmd       = shellquote("${pure_postgres::params::pg_bin_dir}/psql", '-c', $sql, '-d', $db)
  if $unless {
    $unless_test = shellquote("${pure_postgres::params::pg_bin_dir}/psql", '--quiet', '--tuples-only', '-d', $db, '-c', $unless)
    $unless_cmd  = "/bin/test $(${unless_test} | wc -l) -gt 1"
  }  else {
    $unless_cmd  = undef
  }

  exec { "psql ${sql} in ${db}":
    user    => $pure_postgres::params::postgres_user,
    command => $run_cmd,
    unless  => $unless_cmd,
    onlyif  => "/bin/test -f ${pure_postgres::params::pg_data_dir}/PG_VERSION",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

  Pure_postgres::Service::Started['postgres started'] -> Exec["psql ${sql} in ${db}"]

}
