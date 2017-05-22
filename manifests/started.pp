# == Class: pure_postgres::started
#
# Wait until postgres is started

define pure_postgres::started
(
  $retries     = 5,
  $sleep       = 1,
)
{

  $cmd = shellquote( 'bash', '-c', "for ((i=0;i<${retries};i++)); do 
                        echo 'select datname from pg_database' | psql -q -t 2>&1 && break; sleep ${sleep}; done" )

  exec { $title:
    refreshonly => $refreshonly,
    user        => $pure_postgres::params::postgres_user,
    command     => $cmd,
    onlyif      => "test -f '${pure_postgres::params::pg_pid_file}'",
    path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd         => $pure_postgres::params::pg_bin_dir,
    loglevel    => 'debug',
  }

}

