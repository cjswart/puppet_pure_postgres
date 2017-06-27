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

# == Define: pure_postgres::sql::role
#
# Creates a postgres role
define pure_postgres::sql::role
(
  $with_db       = false,
  $password_hash = undef,
  $superuser     = false,
  $searchpath    = undef,
  $replication   = false,
  $canlogin      = false,
)
{

  if $name !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a postgres role: ${name}.")
  }

#SQL identifiers and key words must begin with a letter (a-z, but also letters with diacritical marks and non-Latin letters) 
#or an underscore (_). Subsequent characters in an identifier or key word can be letters, underscores, digits (0-9), or dollar signs ($). 
#Note that dollar signs are not allowed in identifiers according to the letter of the SQL standard, so their use might render applications 
#less portable. The SQL standard will not define a key word that contains digits or starts or ends with an underscore, 
#so identifiers of this form are safe against possible conflict with future extensions of the standard.


  if $password_hash {
    if $password_hash !~ /md5[0-9a-f]{32}/ {
      fail("You can only use a md5 hashed password for pure_postgres::sql::role(${name}). ")
    }
    $pwsql = "password '${password_hash}' LOGIN"
  } else {
    $pwsql = ''
  }

  if $with_db {
    pure_postgres::sql::db { $name:
    }
  }

  if $searchpath {
    $searchpath_str = join($searchpath, ',')
    if $searchpath_str =~ /(?im-x:^[ a-z0-9$,"]*$)/ {
      fail("Your searchpath (${searchpath_str}) should only contain the following characters: [ a-z0-9$,\",]. ")
    }
    $sql_searchpath = "ALTER ROLE ${name} SET search_path TO ${searchpath_str};"
  }
  else {
    $sql_searchpath = ''
  }

  pure_postgres::sql::run_sql { "create role ${name}":
    sql    => "CREATE ROLE ${name} ${pwsql}; ${sql_searchpath}",
    unless => "SELECT * FROM pg_roles where rolname = '${name}'",
  }

  if $with_db {
    pure_postgres::sql::run_sql { "database ${name} owner ${name}":
      sql     => "ALTER DATABASE ${name} OWNER TO ${name};",
      unless  => "SELECT * FROM pg_database where datname = '${name}' and datdba in (select oid from pg_roles where rolname = '${name}');",
      require => [ Pure_postgres::Sql::Db[$name], Pure_postgres::Sql::Run_sql["create role ${name}"] ],
    }
  }

  if $superuser {
    pure_postgres::sql::run_sql { "role ${name} with superuser":
      sql    => "ALTER ROLE ${name} SUPERUSER;",
      unless => "SELECT * FROM pg_roles where rolname = '${name}' and rolsuper;",
    }
  }

  if $replication {
    pure_postgres::sql::run_sql { "role ${name} with replication":
      sql    => "ALTER ROLE ${name} REPLICATION;",
      unless => "SELECT * FROM pg_roles where rolname = '${name}' and rolreplication;",
    }
  }

  if $canlogin {
    pure_postgres::sql::run_sql { "role ${name} with login":
      sql    => "ALTER ROLE ${name} LOGIN;",
      unless => "SELECT * FROM pg_roles where rolname = '${name}' and rolcanlogin;",
    }
  }

}
