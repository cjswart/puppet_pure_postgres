# == Class: pure_postgres::initdb
#
# Module for initing a new postgres cluster
class pure_postgres::initdb
(
) inherits pure_postgres
{

  $initcmd = shellquote("${pure_postgres::params::pg_bin_dir}/initdb", '-D', $pure_postgres::params::pg_data_dir, '-E', $pure_postgres::pg_encoding )

  if $pure_postgres::pg_xlog_dir != "${pure_postgres::params::pg_data_dir}/pg_xlog" {
    $xlogcmd = shellquote( '-X', $pure_postgres::pg_xlog_dir )
  }

  exec { "initdb ${pure_postgres::pg_data_dir}":
    user    => $pure_postgres::params::postgres_user,
    command => "${initcmd} ${xlogcmd}",
    creates => "${pure_postgres::pg_data_dir}/PG_VERSION",
    cwd     => $pure_postgres::params::pg_bin_dir,
    require => [ Package[$pure_postgres::params::pg_package_name], File[$pure_postgres::pg_xlog_dir], File[$pure_postgres::pg_data_dir] ],
  } ->

  exec { "move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf":
    user    => $pure_postgres::params::postgres_user,
    command => "/bin/mv '${pure_postgres::pg_data_dir}/pg_hba.conf' ${pure_postgres::params::pg_etc_dir}/pg_hba.conf",
    unless  => "/bin/test -s '${pure_postgres::params::pg_etc_dir}/pg_hba.conf'",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

  file { "${pure_postgres::pg_data_dir}/pg_hba.conf":
    ensure  => 'absent',
    require => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_hba.conf"],
  }

  exec { "move ${pure_postgres::params::pg_etc_dir}/pg_ident.conf":
    user    => $pure_postgres::params::postgres_user,
    command => "/bin/mv '${pure_postgres::pg_data_dir}/pg_ident.conf' ${pure_postgres::params::pg_etc_dir}/pg_ident.conf",
    unless  => "/bin/test -s '${pure_postgres::params::pg_etc_dir}/pg_ident.conf'",
    cwd     => $pure_postgres::params::pg_bin_dir,
  }

  file { "${pure_postgres::pg_data_dir}/pg_ident.conf":
    ensure  => 'absent',
    require => Exec["move ${pure_postgres::params::pg_etc_dir}/pg_ident.conf"],
  }

  #Add conf.d to postgres.conf
  file_line { 'confd':
    path    => "${pure_postgres::params::pg_etc_dir}/postgresql.conf",
    line    => "include_dir = 'conf.d'",
    require => File["${pure_postgres::params::pg_etc_dir}/postgresql.conf"],
  }

  file { "${pure_postgres::params::pg_etc_dir}/conf.d/defaults.conf":
    ensure  => 'present',
    owner   => $pure_postgres::params::postgres_user,
    group   => $pure_postgres::params::postgres_group,
    mode    => '0640',
    replace => false,
    source  => 'puppet:///modules/pure_postgres/defaults.conf',
    require => File["${pure_postgres::params::pg_etc_dir}/conf.d"],
  }

  file { "${pure_postgres::pg_data_dir}/postgresql.conf":
    ensure => 'absent',
  }

}

