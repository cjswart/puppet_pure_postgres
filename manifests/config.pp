# == Class: pure_postgres::config
#
# Configs postgres after being installed from pure repo
class pure_postgres::config
(
  $do_initdb = $pure_postgres::do_initdb,
) inherits pure_postgres
{

  file { "${pure_postgres::params::pg_bin_dir}/modify_pg_hba.py":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    source  => 'puppet:///modules/pure_postgres/pg_hba.py',
    require => Package[$pure_postgres::params::pg_package],
  }

  file { "${pure_postgres::params::pg_bin_dir}/generate_server_cert.sh":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    content => epp('pure_postgres/generate_server_cert'),
    require => Package[$pure_postgres::params::pg_package],
  }

  # create config directory
  file { "${pure_postgres::params::pg_etc_dir}/conf.d":
    ensure  => 'directory',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0750',
    require => Package[$pure_postgres::params::pg_package],
  }

  if $do_initdb {
    include pure_postgres::initdb
  }

  file { "${pure_postgres::params::pg_etc_dir}/postgresql.conf":
    ensure    => 'present',
    owner     => $pure_postgres::params::postgres_user,
    group     => $pure_postgres::params::postgres_group,
    mode      => '0640',
    source    => 'puppet:///modules/pure_postgres/postgresql.conf',
    show_diff => false,
    require   => Package[$pure_postgres::params::pg_package],
    notify    => Class['pure_postgres::start'],
  }

  file { "${pure_postgres::params::pg_etc_dir}/conf.d/autotune.conf":
    ensure    => 'present',
    owner     => $pure_postgres::params::postgres_user,
    group     => $pure_postgres::params::postgres_group,
    mode      => '0640',
    content   => epp('pure_postgres/autotune.epp'),
    show_diff => false,
    notify    => Class['pure_postgres::restart'],
  }

}

