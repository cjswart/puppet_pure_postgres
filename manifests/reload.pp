# == Class: pure_postgres::reload
#
# Manages service of postgres installed from pure repo

class pure_postgres::reload
(
)
{

  # Do what is needed for postgresql service.
  exec { 'service postgres reload':
    refreshonly => true,
    user        => $pure_postgres::params::postgres_user,
    command     => '/etc/init.d/postgres reload',
    onlyif      => "/bin/test -f ${pure_postgres::params::pg_pid_file}",
    cwd         => $pure_postgres::params::pg_bin_dir,
  }

}
