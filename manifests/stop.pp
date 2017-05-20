# == Class: pure_postgres::stop
#
# Manages service of postgres installed from pure repo

class pure_postgres::stop
(
  $refreshonly = false,
)
{
  # Do what is needed for postgresql service.
  exec { 'service postgres stop':
    user        => $pure_postgres::params::postgres_user,
    command     => '/etc/init.d/postgres stop',
    onlyif      => "/bin/test -f ${pure_postgres::params::pg_pid_file}",
    cwd         => $pure_postgres::params::pg_bin_dir,
    refreshonly => $refreshonly,
  }
}

