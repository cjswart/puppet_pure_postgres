# == Class: pure_postgres::ssl
#
# Configs a server certificate for postgres 
class pure_postgres::ssl
(
  $data      = $pure_postgres::pg_data_dir,
  $cn        = $pure_postgres::pg_ssl_cn,
  $org       = $pure_postgres::params::pg_ssl_org,
  $country   = $pure_postgres::params::pg_ssl_country,
  $state     = $pure_postgres::params::pg_ssl_state,
  $locality  = $pure_postgres::params::pg_ssl_locality,
)
{
  $cmd = shellquote( "${pure_postgres::pg_bin_dir}/generate_server_cert.sh", '-data', $data, '-cn', $cn, '-org', $org, '-country', $country, '-state', $state, '-locality', $locality )

  exec { "exec ${cmd}":
    user    => $pure_postgres::postgres_user,
    command => $cmd,
    require => File["${pure_postgres::params::pg_bin_dir}/generate_server_cert.sh"],
    creates => "${pure_postgres::pg_data_dir}/server.crt",
  } ->

  file { "${pure_postgres::params::pg_etc_dir}/conf.d/ssl.conf":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0640',
    replace => false,
    source  => 'puppet:///modules/pure_postgres/ssl.conf',
    require => File["${pure_postgres::params::pg_etc_dir}/conf.d"],
  }
}
