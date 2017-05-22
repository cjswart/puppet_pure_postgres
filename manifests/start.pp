# == Class: pure_postgres::start
#
# Allow postgres service to be started. Forcefull, or by notification

class pure_postgres::start
(
  $refreshonly = ! pure_postgres::manage_service,
)
{

  if $pure_postgres::manage_service {
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

  pure_postgres::started {'postgres started':
  }

  Exec['service postgres start'] ~> Pure_postgres::Started['postgres started']

}
