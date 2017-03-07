# == Class: pure_postgres::postgres_user
#
# Create postgres user and groups
class pure_postgres::postgres_user
(
) inherits pure_postgres::params
{

  file { "/home/${pure_postgres::params::postgres_user}":
    ensure => directory,
    owner  => $pure_postgres::params::postgres_user,
    group  => $pure_postgres::params::postgres_group,
  }

  group { 'pgpure':
    ensure => present,
  } ->

  user { $pure_postgres::params::postgres_user:
    ensure     => present,
    comment    => 'postgres server',
    groups     => 'pgpure',
    home       => "/home/${pure_postgres::params::postgres_user}",
    managehome => true,
    shell      => '/bin/bash',
    system     => true,
  } ->

  exec { 'Generate ssh keys for postgres user':
    user    => $pure_postgres::params::postgres_user,
    command => '/usr/bin/ssh-keygen -t ed25519 -P "" -f ~/.ssh/id_ed25519',
    creates => "/home/${pure_postgres::params::postgres_user}/.ssh/id_ed25519",
    cwd     => "/home/${pure_postgres::params::postgres_user}",
  }

}
