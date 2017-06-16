# == Class: pure_postgres::config
#
# Configs postgres after being installed from pure repo
class pure_postgres::config
(
  $do_initdb = $pure_postgres::do_initdb,
) inherits pure_postgres
{

  if ! defined(File['/etc/facter/facts.d']) {
    file { [  '/etc/facter', '/etc/facter/facts.d' ]:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
  }

  #create facts script to add postgres ssh keys to facts
  file { '/etc/facter/facts.d/pure_postgres_facts.sh':
    ensure  => file,
    content => epp('pure_postgres/pure_postgres_facts.epp'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/facter/facts.d'],
  } 

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

