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

# == Class: pure_postgres::initdb
#
# Module for initing a new postgres cluster
class pure_postgres::initdb
(
) inherits pure_postgres
{

  $initcmd = shellquote("${pure_postgres::params::pg_bin_dir}/initdb", '-D', $pure_postgres::params::pg_data_dir,
                        '-E', $pure_postgres::pg_encoding )

  if $pure_postgres::pg_xlog_dir != "${pure_postgres::params::pg_data_dir}/pg_xlog" {
    $xlogcmd = shellquote( '-X', $pure_postgres::pg_xlog_dir )
  }

  exec { "initdb ${pure_postgres::pg_data_dir}":
    user    => $pure_postgres::params::postgres_user,
    command => "${initcmd} ${xlogcmd}",
    creates => "${pure_postgres::pg_data_dir}/PG_VERSION",
    cwd     => $pure_postgres::params::pg_bin_dir,
    require => [ Package[$pure_postgres::params::pg_package], File[$pure_postgres::pg_xlog_dir], File[$pure_postgres::pg_data_dir] ],
  }

  -> exec { "move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf":
    user    => $pure_postgres::params::postgres_user,
    command => "/bin/mv '${pure_postgres::pg_data_dir}/pg_hba.conf' ${pure_postgres::params::pg_etc_dir}/pg_hba.conf",
    unless  => "/bin/test -s '${pure_postgres::params::pg_etc_dir}/pg_hba.conf'",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

  pure_postgres::pg_hba {'pg_hba entry for local':
    connection_type => 'local',
    database        => 'all',
    user            => 'all',
    method          => 'peer',
    state           => 'present',
    require         => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf"],
  }

  pure_postgres::pg_hba {'pg_hba entry for localhost':
    connection_type => 'host',
    database        => 'all',
    user            => 'all',
    method          => 'md5',
    state           => 'present',
    source          => '127.0.0.1/32',
    require         => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf"],
  }

  pure_postgres::pg_hba {'pg_hba entry for localhost IPv6':
    connection_type => 'host',
    database        => 'all',
    user            => 'all',
    method          => 'md5',
    state           => 'present',
    source          => '::1/128',
    require         => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf"],
  }

  if $pure_postgres::do_ssl {
    class{ 'pure_postgres::ssl':
      require => Exec["initdb ${pure_postgres::pg_data_dir}"],
    }
  }

  file { "${pure_postgres::pg_data_dir}/pg_hba.conf":
    ensure  => 'absent',
    require => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf"],
  }

  exec { "move ${pure_postgres::params::pg_etc_dir}/pg_ident.conf":
    user    => $pure_postgres::params::postgres_user,
    command => "/bin/mv '${pure_postgres::pg_data_dir}/pg_ident.conf' ${pure_postgres::params::pg_etc_dir}/pg_ident.conf",
    unless  => "/bin/test -s '${pure_postgres::params::pg_etc_dir}/pg_ident.conf'",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

  file { "${pure_postgres::pg_data_dir}/pg_ident.conf":
    ensure  => 'absent',
    require => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_ident.conf"],
  }

  #Add conf.d to postgres.conf
#  file_line { 'confd':
#    path    => "${pure_postgres::params::pg_etc_dir}/postgresql.conf",
#    line    => "include_dir = 'conf.d'",
#    require => File["${pure_postgres::params::pg_etc_dir}/postgresql.conf"],
#  }

  file { "${pure_postgres::params::pg_etc_dir}/conf.d/defaults.conf":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0640',
    replace => false,
    source  => 'puppet:///modules/pure_postgres/defaults.conf',
    require => File["${pure_postgres::params::pg_etc_dir}/conf.d"],
  }

  file { "${pure_postgres::pg_data_dir}/postgresql.conf":
    ensure  => 'absent',
    require => Package[$pure_postgres::params::pg_package],
    before  => Class['pure_postgres::start'],
  }

}

