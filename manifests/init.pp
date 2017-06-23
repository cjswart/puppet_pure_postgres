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

# == Class: pure_postgres
#
# Module for doing postgres stuff with pure distribution.
class pure_postgres
(
  $repo           = $pure_postgres::params::repo,
  $version        = $pure_postgres::params::version,
  $repo_package   = $pure_postgres::params::repo_package,
  $do_initdb      = $pure_postgres::params::do_initdb,
  $pg_encoding    = $pure_postgres::params::pg_encoding,
  $pg_data_dir    = $pure_postgres::params::pg_data_dir,
  $pg_xlog_dir    = $pure_postgres::params::pg_xlog_dir,
  $do_ssl         = $pure_postgres::params::do_ssl,
  $pg_ssl_cn      = $pure_postgres::params::pg_ssl_cn,
  $manage_service = $pure_postgres::params::manage_service,
  $autorestart    = $pure_postgres::params::autorestart,
) inherits pure_postgres::params
{

  include pure_postgres::service
  include pure_postgres::install
  include pure_postgres::config

}

