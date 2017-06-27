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

# == Define: pure_postgres::sql::db
# Creates a postgres database
define pure_postgres::sql::db (
  $owner   = undef,
)
{

  if $name !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${name}.")
  }

  pure_postgres::sql::run_sql { "create database ${name}":
    sql    => "CREATE DATABASE \"${name}\";",
    unless => "SELECT * FROM pg_database where datname = '${name}';",
  }

  if $owner {
    if $owner !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
      notify { "Not a valid owner for a database: ${owner}.": }
    }

    pure_postgres::sql::run_sql { "database ${name} owner ${owner}":
      sql     => "ALTER DATABASE \"${name}\" OWNER TO \"${owner}\";",
      require => pure_postgres::sql::run_sql["create database ${name}"],
    }
  }

}

