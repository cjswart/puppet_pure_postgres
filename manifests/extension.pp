# == Define: pure_postgres::extension
# Installs a postgres database extension
define pure_postgres::extension (
  $db    = 'postgres',
)
{

  if $name !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database extension: ${name}.")
  }

  if $db !~ /(?im-x:^[a-z_][a-z_0-9$]*$)/ {
    fail("Not a valid name for a database: ${db}.")
  }

  pure_postgres::run_sql { "create extension ${name} in database ${db}":
    sql    => "CREATE EXTENSION \"${name}\";",
    unless => "SELECT * FROM pg_extension where extname = '${name}';",
    db     => $db,
  }

}

