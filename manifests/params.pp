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

# == Class pure_postgres::params
class pure_postgres::params
{
  $repo               = 'http://base.splendiddata.com/postgrespure'
  $version            = '4'
  $repo_package       = 'postgrespure-release'
  $pg_version         = $version ? {
    '1' => '9.3',
    '2' => '9.4',
    '3' => '9.5',
    '4' => '9.6',
  }

  $pg_package         = "postgres-${pg_version}"
  $pg_package_libs    = "${pg_package}-libs"
  $pg_package_contrib = "${pg_package}-contrib"
  $pg_etc_dir         = "/etc/pgpure/postgres/${pg_version}/data"
  $pg_data_dir        = "/var/pgpure/postgres/${pg_version}/data"
  $pg_xlog_dir        = "${pg_data_dir}/pg_xlog"
  $pg_bin_dir         = "/usr/pgpure/postgres/${pg_version}/bin"
  $pg_log_dir         = '/var/log/pgpure/postgres'
  $pg_encoding        = 'UTF8'

  $do_initdb          = true
  $pg_hba_conf        = "${pg_etc_dir}/pg_hba.conf"
  $pg_ident_conf      = "${pg_etc_dir}/pg_ident.conf"
  $postgresql_conf    = "${pg_etc_dir}/postgresql.conf"
  $pg_pid_file        = "${pg_data_dir}/postmaster.pid"

  $postgres_user      = 'postgres'
  $postgres_group     = 'postgres'
  $do_ssl             = true
  $pg_ssl_cn          = $::fqdn
  $pg_ssl_org         = '.'
  $pg_ssl_country     = 'NL'
  $pg_ssl_state       = '.'
  $pg_ssl_locality    = '.'

  $manage_service     = true
  $autorestart        = true
}

