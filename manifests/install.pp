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

# == Class: pure_postgres::install
#
# Installs postgres from pure repo in a bare format (without running initdb on $pg_data_dir)
class pure_postgres::install
(
  $pg_data_dir = $pure_postgres::pg_data_dir,
  $pg_xlog_dir = $pure_postgres::pg_xlog_dir,
)
{
  #Doing this before installing rpm prevents initdb in rpm,
  #which helps in idempotency state detection of new cluster.

  include pure_postgres::config::postgres_user

  file { [ '/var/pgpure', '/var/pgpure/postgres', "/var/pgpure/postgres/${pure_postgres::params::pg_version}" ]:
    ensure => 'directory',
    owner  => $pure_postgres::params::postgres_user,
    group  => $pure_postgres::params::postgres_group,
    mode   => '0700',
  }

  if $pg_data_dir == $pure_postgres::params::pg_data_dir {
    file { $pure_postgres::params::pg_data_dir:
      ensure  => 'directory',
      owner   => $pure_postgres::params::postgres_user,
      group   => $pure_postgres::params::postgres_group,
      mode    => '0700',
      require => File["/var/pgpure/postgres/${pure_postgres::params::pg_version}"],
    }
  }
  else {
    if ! defined(File[$pg_data_dir]) {
      file { $pg_data_dir:
        ensure => 'directory',
        owner  => $pure_postgres::params::postgres_user,
        group  => $pure_postgres::params::postgres_group,
        mode   => '0700',
      }
    }
    file { $pure_postgres::params::pg_data_dir:
      ensure  => 'link',
      target  => $pg_data_dir,
      owner   => $pure_postgres::params::postgres_user,
      group   => $pure_postgres::params::postgres_group,
      mode    => '0700',
      require => File["/var/pgpure/postgres/${pure_postgres::params::pg_version}", $pg_data_dir],
    }
  }

  if ! defined(File[$pg_xlog_dir]) {
    file { $pg_xlog_dir:
      ensure => 'directory',
      owner  => $pure_postgres::params::postgres_user,
      group  => $pure_postgres::params::postgres_group,
      mode   => '0700',
    }
  }

  package {$pure_postgres::params::pg_package:
    ensure  => 'installed',
    require => File[ $pure_postgres::params::pg_data_dir ],
  }

}

