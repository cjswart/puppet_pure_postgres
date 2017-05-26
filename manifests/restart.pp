# == Class: pure_postgres::restart
#
# Manages service of postgres installed from pure repo

class pure_postgres::restart
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

    Exec['service postgres restart'] -> Pure_postgres::Started['postgres restarted']
  }

  pure_postgres::started { 'postgres restarted':
  }

}
