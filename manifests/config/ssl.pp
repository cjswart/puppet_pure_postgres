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

# == Class: pure_postgres::ssl
#
# Configs a server certificate for postgres 
class pure_postgres::ssl
(
  $data      = $pure_postgres::pg_data_dir,
  $cn        = $pure_postgres::pg_ssl_cn,
  $org       = $pure_postgres::params::pg_ssl_org,
  $country   = $pure_postgres::params::pg_ssl_country,
  $state     = $pure_postgres::params::pg_ssl_state,
  $locality  = $pure_postgres::params::pg_ssl_locality,
)
{
  $cmd = shellquote( "${pure_postgres::pg_bin_dir}/generate_server_cert.sh", '-data', $data, '-cn', $cn, '-org', $org,
                      '-country', $country, '-state', $state, '-locality', $locality )

  exec { "exec ${cmd}":
    user    => $pure_postgres::postgres_user,
    command => $cmd,
    require => File["${pure_postgres::params::pg_bin_dir}/generate_server_cert.sh"],
    creates => "${pure_postgres::pg_data_dir}/server.crt",
  }

  -> file { "${pure_postgres::params::pg_etc_dir}/conf.d/ssl.conf":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0640',
    replace => false,
    source  => 'puppet:///modules/pure_postgres/ssl.conf',
    require => File["${pure_postgres::params::pg_etc_dir}/conf.d"],
  }
}
