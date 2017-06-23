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

# == Define: pure_postgres::grant
# Grants a permission on a postgres object to a postgres user
define pure_postgres::grant (
  $permission  = undef,
  $with_grant  = false,
  $object      = undef,
  $object_type = undef,
  $role        = undef,
  $db          = 'postgres',
)
{

  if ! ($permission.downcase in [ 'execute', 'select', 'insert', 'update', 'delete', 'truncate', 'references', 'trigger', 'usage',
                                  'connect', 'temporary', 'temp', 'all privilleges', 'all', 'create']) {
    fail("Not a valid permission ${permission} on ${object} for ${role}.")
  }

  $unless = $object_type.downcase ? {
    'table'                   => "select 'yes' where has_table_privilege('${role}', '${object}', '${permission}')",
    'sequence'                => "select 'yes' where has_sequence_privilege('${role}', '${object}', '${permission}')",
    'database'                => "select 'yes' where has_database_privilege('${role}', '${object}', '${permission}')",
    'domain'                  => "select 'yes' where has_type_privilege('${role}', '${object}', '${permission}')",
    'foreign data wrapper'    => "select 'yes' where has_foreign_data_wrapper_privilege('${role}', '${object}', '${permission}')",
    'foreign server'          => "select 'yes' where has_server_privilege('${role}', '${object}', '${permission}')",
    'function'                => "select 'yes' where has_function_privilege('${role}', '${object}', '${permission}')",
    'all functions in schema' => "select func from (
                                     select specific_schema||'.'||specific_name||'()' func from information_schema.routines 
                                     where routine_type = 'FUNCTION' and specific_schema='${object}') tmp 
                                  where not has_function_privilege('${role}', '${object}', '${permission}')",
    'language'                => "select 'yes' where has_language_privilege('${role}', '${object}', '${permission}')",
    'schema'                  => "select 'yes' where has_schema_privilege('${role}', '${object}', '${permission}')",
    'tablespace'              => "select 'yes' where has_tablespace_privilege('${role}', '${object}', '${permission}')",
    'type'                    => "select 'yes' where has_type_privilege('${role}', '${object}', '${permission}')",
    default                   => 'INVALID',
  }

  if $unless == 'INVALID' {
    fail("Not a valid object type ${object_type.downcase} for object ${object} when trying to grant for ${role}.")
  }

  if $role !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database role: ${role}.")
  }


  if $object !~ /(?im-x:^[a-z_0-9$ ().,]+$)/ {
    fail("Not a valid name for a database object: ${object}.")
  }

  if $with_grant {
    $sql_grant = 'with grant '
  }
  else {
    $sql_grant = ''
  }

  $sql    = "grant ${permission} ${sql_grant}on ${object_type} ${object} to ${role};"

  pure_postgres::run_sql { "${db}: ${sql}":
    sql    => $sql,
    unless => $unless,
    db     => $db,
  }

}

