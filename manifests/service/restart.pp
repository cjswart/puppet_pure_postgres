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

# == Class: pure_postgres::service::restart
#
# Manages service of postgres installed from pure repo

class pure_postgres::service::restart
(
)
{

  if $pure_postgres::autorestart {
    # Restart postgresql service.
    exec { 'service postgres restart':
      refreshonly => true,
      user        => $pure_postgres::params::postgres_user,
      command     => '/etc/init.d/postgres restart',
      onlyif      => "test -f '${pure_postgres::params::pg_data_dir}/PG_VERSION'",
      path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
      cwd         => $pure_postgres::params::pg_bin_dir,
    }

    Exec['service postgres restart'] -> Pure_postgres::Service::Started['postgres restarted']
  }

  pure_postgres::service::started { 'postgres restarted':
  }

}
