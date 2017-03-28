# == Class: pure_postgres::started
#
# Wait until postgres is started

class pure_postgres::started
(
  $refreshonly = false,
  $retries     = 5,
  $sleep       = 1,
)
{

  $cmd = shellquote( 'bash', '-c', "for ((i=0;i<${retries};i++)); do 
                        echo 'select datname from pg_database' | psql -q -t 2>&1 && break; sleep ${sleep}; done" )

  exec { 'Wait for postgres to finish starting':
    refreshonly => $refreshonly,
    user        => $pure_postgres::params::postgres_user,
    command     => $cmd,
    onlyif      => "test -f '${pure_postgres::params::pg_pid_file}'",
    path        => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd         => $pure_postgres::params::pg_bin_dir,
    loglevel    => 'debug',
  }

}

