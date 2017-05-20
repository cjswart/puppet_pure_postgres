# == Class: pure_postgres::service
#
# Manages service of postgres installed from pure repo

class pure_postgres::service
(
)
{

  #this also contains pure_postgres::start and pure_postgres::stop
  if ! defined(Class['pure_postgres::restart']) {
    class { 'pure_postgres::restart':
      refreshonly => true,
    }
  }

  if ! defined(Class['pure_postgres::reload']) {
    class { 'pure_postgres::reload':
      refreshonly => true,
    }
  }

  if ! defined(Class['pure_postgres::started']) {
    class { 'pure_postgres::started':
      refreshonly => true,
    }
  }

  Class['pure_postgres::stop'] -> Class['pure_postgres::start']
  Class['pure_postgres::start'] ~> Class['pure_postgres::started']
  Class['pure_postgres::started'] -> Class['pure_postgres::reload']
  Class['pure_postgres::stop'] -> Class['pure_postgres::start']

}

