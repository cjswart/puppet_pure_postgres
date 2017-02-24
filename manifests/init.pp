# == Class: pure_postgres
#
# Module for doing postgres stuff with pure distribution.
class pure_postgres
(
  $repo              = $pure_postgres::params::repo,
  $version           = $pure_postgres::params::version,
  $repo_package_name = $pure_postgres::params::repo_package_name,
  $package_version   = $pure_postgres::params::package_version,
  $do_initdb         = $pure_postgres::params::do_initdb,
  $pg_encoding       = $pure_postgres::params::pg_encoding,
  $pg_data_dir       = $pure_postgres::params::pg_data_dir,
  $pg_xlog_dir       = $pure_postgres::params::pg_xlog_dir,
) inherits pure_postgres::params
{

  class { 'pure_postgres::install':
  } ->

  class { 'pure_postgres::config':
  }

}

