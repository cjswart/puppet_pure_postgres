# == Class: pure_postgres::repo
#
# Installs pure repo
class pure_postgres::repo
(
  $repo            = $pure_postgres::params::repo,
  $version         = $pure_postgres::params::version,
  $repo_package    = $pure_postgres::params::repo_package,
  $support_package = false,
) inherits pure_postgres::params
# inherits is added to force defining pure_postgres::params. WIthout it, $version might be undef and not $pure_postgres::params::version
{
  $dist = $::operatingsystem ?
  {
    'Centos' => 'centos'
  }
  $dist_version = $facts['os']['release']['major']

  $repo_url = "${repo}/${version}/${dist}/${dist_version}/"

  yumrepo { 'PostgresPURE':
    baseurl  => $repo_url,
    descr    => 'Postgres PURE',
    enabled  => 1,
    gpgcheck => 0
  }

  if $support_package {
    Package { $support_package:
      require => Yumrepo['PostgresPURE'],
    }
  }

}

