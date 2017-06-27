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

# == Class: pure_postgres::config
#
# Configs postgres after being installed from pure repo
class pure_postgres::config
(
  $do_initdb = $pure_postgres::do_initdb,
) inherits pure_postgres
{

  file { "${pure_postgres::pg_bin_dir}/pure_postgres_releasenotes.txt":
    ensure => 'file',
    source => 'puppet:///modules/pure_postgres/releasenotes.txt',
    owner  => $pure_postgres::config::postgres_user,
    group  => $pure_postgres::postgres_group,
    mode   => '0750',
  }

  if ! defined(File['/etc/facter/facts.d']) {
    file { [  '/etc/facter', '/etc/facter/facts.d' ]:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
  }

  #create facts script to add postgres ssh keys to facts
  file { '/etc/facter/facts.d/pure_postgres_facts.sh':
    ensure  => file,
    content => epp('pure_postgres/pure_postgres_facts.epp'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/facter/facts.d'],
  }

  file { "${pure_postgres::params::pg_bin_dir}/modify_pg_hba.py":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    source  => 'puppet:///modules/pure_postgres/pg_hba.py',
    require => Package[$pure_postgres::params::pg_package],
  }

  file { "${pure_postgres::params::pg_bin_dir}/generate_server_cert.sh":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    content => epp('pure_postgres/generate_server_cert'),
    require => Package[$pure_postgres::params::pg_package],
  }

  # create config directory
  file { "${pure_postgres::params::pg_etc_dir}/conf.d":
    ensure  => 'directory',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    require => Package[$pure_postgres::params::pg_package],
  }

  if $do_initdb {
    include pure_postgres::config::initdb
  }

  file { "${pure_postgres::params::pg_etc_dir}/postgresql.conf":
    ensure    => 'present',
    owner     => $pure_postgres::params::postgres_user,
    group     => $pure_postgres::params::postgres_group,
    mode      => '0640',
    source    => 'puppet:///modules/pure_postgres/postgresql.conf',
    show_diff => false,
    require   => Package[$pure_postgres::params::pg_package],
    notify    => Class['pure_postgres::service::start'],
  }

  file { "${pure_postgres::params::pg_etc_dir}/conf.d/autotune.conf":
    ensure    => 'present',
    owner     => $pure_postgres::params::postgres_user,
    group     => $pure_postgres::params::postgres_group,
    mode      => '0640',
    content   => epp('pure_postgres/autotune.epp'),
    show_diff => false,
    notify    => Class['pure_postgres::service::restart'],
  }

}

