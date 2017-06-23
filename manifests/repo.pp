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

# == Class: pure_postgres::repo
#
# Installs pure repo
class pure_postgres::repo
(
  $repo            = $pure_postgres::params::repo,
  $version         = $pure_postgres::params::version,
  $repo_package    = $pure_postgres::params::repo_package,
  $support_package = false,
) inherits pure_postgres::params
# inherits is added to force defining pure_postgres::params. WIthout it, $version might be undef and not $pure_postgres::params::version
{
  $dist = $::operatingsystem ?
  {
    'Centos' => 'centos'
  }
  $dist_version = $facts['os']['release']['major']

  $repo_url = "${repo}/${version}/${dist}/${dist_version}/"

  yumrepo { 'PostgresPURE':
    baseurl  => $repo_url,
    descr    => 'Postgres PURE',
    enabled  => 1,
    gpgcheck => 0
  }

  if $support_package {
    Package { $support_package:
      require => Yumrepo['PostgresPURE'],
    }
  }

}

