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

# == Define: pure_postgres::extension
# Installs a postgres database extension
define pure_postgres::extension (
  $db    = 'postgres',
)
{

  if $name !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database extension: ${name}.")
  }

  if $db !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${db}.")
  }

  pure_postgres::run_sql { "create extension ${name} in database ${db}":
    sql    => "CREATE EXTENSION \"${name}\";",
    unless => "SELECT * FROM pg_extension where extname = '${name}';",
    db     => $db,
  }

}

