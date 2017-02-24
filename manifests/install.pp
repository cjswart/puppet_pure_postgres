# == Class: pure_postgres::install
#
# Installs postgres from pure repo in a bare format (without running initdb on $pg_data_dir)
class pure_postgres::install
(
  $pg_data_dir = $pure_postgres::pg_data_dir,
  $pg_xlog_dir = $pure_postgres::pg_xlog_dir,
) inherits pure_postgres
{
  #Doing this before installing rpm prevents initdb in rpm,
  #which helps in idempotency state detection of new cluster.

  include pure_postgres::postgres_user

  file { [ '/var/pgpure', '/var/pgpure/postgres', "/var/pgpure/postgres/$::{pg_version}" ]:
    ensure => 'directory',
    owner  => $::postgres_user,
    group  => $::postgres_group,
    mode   => '0700',
  }

  if $pg_data_dir == $pure_postgres::params::pg_data_dir {
    file { $pure_postgres::params::pg_data_dir:
      ensure  => 'directory',
      owner   => $::postgres_user,
      group   => $::postgres_group,
      mode    => '0700',
      require => File["/var/pgpure/postgres/$::{pg_version}"],
    }
  }
  else {
    if ! defined(File[$pg_data_dir]) {
      file { $pg_data_dir:
        ensure => 'directory',
        owner  => $::postgres_user,
        group  => $::postgres_group,
        mode   => '0700',
      }
    }
    file { $pure_postgres::params::pg_data_dir:
      ensure  => 'link',
      target  => $::pg_data_dir,
      owner   => $::postgres_user,
      group   => $::postgres_group,
      mode    => '0700',
      require => File["/var/pgpure/postgres/$::{pg_version}", $::pg_data_dir],
    }
  }

  if ! defined(File[$pg_xlog_dir]) {
    file { $pg_xlog_dir:
      ensure => 'directory',
      owner  => $::postgres_user,
      group  => $::postgres_group,
      mode   => '0700',
    }
  }

  package {$::pg_package_name:
    ensure  => 'installed',
    require => File[ $pure_postgres::params::pg_data_dir ],
  }

}

