# == Class: pure_postgres::restart
#
# Manages service of postgres installed from pure repo

class pure_postgres::restart
(
  $refreshonly = false,
)
{

  if ! defined(Class['pure_postgres::stop']) {
    class {'pure_postgres::stop':
      refreshonly => $refreshonly,
    }
  }

  if ! defined(Class['pure_postgres::start']) {
    class {'pure_postgres::start':
      refreshonly => $refreshonly,
    }
  }

  Class['pure_postgres::stop'] ~>  Class['pure_postgres::start']
}

