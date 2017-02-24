# == Class: pure_postgres::start
#
# Manages service of postgres installed from pure repo

class pure_postgres::start
(
) inherits pure_postgres
{

  $cmd = shellquote( 'bash', '-c', "for ((i=0;i<5;i++)); do echo 'select datname from pg_database' | psql -q -t > /dev/null 2>&1 && break; sleep 1; done" )

  # Do what is needed for postgresql service.
  exec { 'service postgres start':
    user    => $pure_postgres::params::postgres_user,
    command => '/etc/init.d/postgres start',
    creates => $pure_postgres::params::pg_pid_file,
    onlyif  => "test -f '${pure_postgres::params::pg_data_dir}/PG_VERSION'",
    path    => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd     => $pure_postgres::params::pg_bin_dir,
  } ->

  exec { 'wait for postgres to finish starting':
    user     => $pure_postgres::params::postgres_user,
    command  => $cmd,
    onlyif   => "test -f '${pure_postgres::params::pid_file}",
    path     => "${pure_postgres::params::pg_bin_dir}:/usr/local/bin:/bin",
    cwd      => $pure_postgres::params::pg_bin_dir,
    loglevel => 'debug',
  }

}

