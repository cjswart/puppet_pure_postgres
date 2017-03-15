# == Deinition: pure_postgres::run_sql
define pure_postgres::run_sql (
  $sql,
  $unless = undef,
  $user   = $pure_postgres::params::pg_user,
  $db     = 'postgres',
)
{

  assert_private('run_sql is for internal pure_postgres purposes only')

  if $db !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${db}.")
  }

  $run_cmd       = shellquote("${pure_postgres::params::pg_bin_dir}/psql", '-c', $sql, '-d', $db)
  if $unless {
    $unless_test = shellquote("${pure_postgres::params::pg_bin_dir}/psql", '--quiet', '--tuples-only', '-d', $db, '-c', $unless)
    $unless_cmd  = "/bin/test $(${unless_test} | wc -l) -gt 1"
  }  else {
    $unless_cmd  = undef
  }

  exec { "psql ${sql} in ${db}":
    user    => $pure_postgres::params::postgres_user,
    command => $run_cmd,
    unless  => $unless_cmd,
    onlyif  => "/bin/test -f ${pure_postgres::params::pg_data_dir}/PG_VERSION",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

}
