# == Class: pure_postgres::reload
#
# Manages service of postgres installed from pure repo

class pure_postgres::reload
(
) inherits pure_postgres
{
  # Do what is needed for postgresql service.
  exec { "service postgres reload":
    user        => $postgres_user,
    command     => "/etc/init.d/postgres reload",
    onlyif      => "/bin/test -f $pg_pid_file",
    cwd         => $pg_bin_dir,
    refreshonly => true,
  }
}

