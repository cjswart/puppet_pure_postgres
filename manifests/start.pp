# == Class: pure_postgres::start
#
# Manages service of postgres installed from pure repo

class pure_postgres::start
(
  $refreshonly = false,
)
{

  # Do what is needed for postgresql service.
  exec { 'service postgres start':
    refreshonly => $refreshonly,
    user        => $pure_postgres::params::postgres_user,
    command     => '/etc/init.d/postgres start',
    creates     => $pure_postgres::params::pg_pid_file,
    onlyif      => "test -f '${pure_postgres::params::pg_data_dir}/PG_VERSION'",
    path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd         => $pure_postgres::params::pg_bin_dir,
  }

}

