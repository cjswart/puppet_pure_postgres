# == Class pure_postgres::params
class pure_postgres::params
{
  $repo               = 'http://base.splendiddata.com/postgrespure'
  $version            = '4'
  $repo_package       = 'postgrespure-release'
  $pg_version         = $version ? {
    '1' => '9.3',
    '2' => '9.4',
    '3' => '9.5',
    '4' => '9.6',
  }

  $pg_package         = "postgres-${pg_version}"
  $pg_package_libs    = "${pg_package}-libs"
  $pg_package_contrib = "${pg_package}-contrib"
  $pg_etc_dir         = "/etc/pgpure/postgres/${pg_version}/data"
  $pg_data_dir        = "/var/pgpure/postgres/${pg_version}/data"
  $pg_xlog_dir        = "${pg_data_dir}/pg_xlog"
  $pg_bin_dir         = "/usr/pgpure/postgres/${pg_version}/bin"
  $pg_log_dir         = '/var/log/pgpure/postgres'
  $pg_encoding        = 'UTF8'

  $do_initdb          = true
  $pg_hba_conf        = "${pg_etc_dir}/pg_hba.conf"
  $pg_ident_conf      = "${pg_etc_dir}/pg_ident.conf"
  $postgresql_conf    = "${pg_etc_dir}/postgresql.conf"
  $pg_pid_file        = "${pg_data_dir}/postmaster.pid"

  $postgres_user      = 'postgres'
  $postgres_group     = 'postgres'
  $do_ssl             = true
  $pg_ssl_cn          = $::fqdn
  $pg_ssl_org         = '.'
  $pg_ssl_country     = 'NL'
  $pg_ssl_state       = '.'
  $pg_ssl_locality    = '.'

  $manage_service     = true
}

