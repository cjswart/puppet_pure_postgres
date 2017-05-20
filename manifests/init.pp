# == Class: pure_postgres
#
# Module for doing postgres stuff with pure distribution.
class pure_postgres
(
  $repo            = $pure_postgres::params::repo,
  $version         = $pure_postgres::params::version,
  $repo_package    = $pure_postgres::params::repo_package,
  $do_initdb       = $pure_postgres::params::do_initdb,
  $pg_encoding     = $pure_postgres::params::pg_encoding,
  $pg_data_dir     = $pure_postgres::params::pg_data_dir,
  $pg_xlog_dir     = $pure_postgres::params::pg_xlog_dir,
  $do_ssl          = $pure_postgres::params::do_ssl,
  $pg_ssl_cn       = $pure_postgres::params::pg_ssl_cn,
) inherits pure_postgres::params
{

  include pure_postgres::service

  class { 'pure_postgres::install':
  } ->

  class { 'pure_postgres::config':
  }

}

