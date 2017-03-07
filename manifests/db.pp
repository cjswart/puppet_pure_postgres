# == Define: pure_postgres::db
# Creates a postgres database
define pure_postgres::db (
  $owner   = undef,
)
{

  if $name !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${name}.")
  }

  pure_postgres::run_sql { "create database ${name}":
    sql    => "CREATE DATABASE \"${name}\";",
    unless => "SELECT * FROM pg_database where datname = '${name}';",
  }

  if $owner {
    if $owner !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
      notify { "Not a valid owner for a database: ${owner}.": }
    }

    pure_postgres::run_sql { "database ${name} owner ${owner}":
      sql     => "ALTER DATABASE \"${name}\" OWNER TO \"${owner}\";",
      require => pure_postgres::run_sql["create database ${name}"],
    }
  }

}

