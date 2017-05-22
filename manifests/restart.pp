# == Class: pure_postgres::restart
#
# Manages service of postgres installed from pure repo

class pure_postgres::restart
(
  $refreshonly = true,
)
{

  # Restart postgresql service.
  exec { 'service postgres restart':
    refreshonly => $refreshonly,
    user        => $pure_postgres::params::postgres_user,
    command     => '/etc/init.d/postgres restart',
    onlyif      => "test -f '${pure_postgres::params::pg_data_dir}/PG_VERSION'",
    path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd         => $pure_postgres::params::pg_bin_dir,
  } ->

  pure_postgres::started { 'postgres restarted':
  }

}
