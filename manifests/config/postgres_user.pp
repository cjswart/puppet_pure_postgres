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

# == Class: pure_postgres::config::postgres_user
#
# Create postgres user and groups
class pure_postgres::config::postgres_user
(
) inherits pure_postgres::params
{

  file { "/home/${pure_postgres::params::postgres_user}":
    ensure => directory,
    owner  => $pure_postgres::params::postgres_user,
    group  => $pure_postgres::params::postgres_group,
  }

  group { 'pgpure':
    ensure => present,
  }

  -> user { $pure_postgres::params::postgres_user:
    ensure     => present,
    comment    => 'postgres server',
    groups     => 'pgpure',
    home       => "/home/${pure_postgres::params::postgres_user}",
    managehome => true,
    shell      => '/bin/bash',
    system     => true,
  }

  -> exec { 'Generate ssh keys for postgres user':
    user    => $pure_postgres::params::postgres_user,
    command => '/usr/bin/ssh-keygen -t ed25519 -P "" -f ~/.ssh/id_ed25519',
    creates => "/home/${pure_postgres::params::postgres_user}/.ssh/id_ed25519",
    cwd     => "/home/${pure_postgres::params::postgres_user}",
  }

}
