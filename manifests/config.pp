# == Class: pure_postgres::config
#
# Configs postgres after being installed from pure repo
class pure_postgres::config
(
  $do_initdb         = $pure_postgres::do_initdb,
) inherits pure_postgres 
{

   file { "$pg_bin_dir/modify_pg_hba.py":
      ensure  => 'present',
      owner   => $postgres_user,
      group   => $postgres_group,
      mode    => '0750',
      source  => 'puppet:///modules/pure_postgres/pg_hba.py',
      require => Package[$pg_package_name],
   }

   # create config directory
   file { "${pg_etc_dir}/conf.d":
      ensure  => 'directory',
      owner   => $postgres_user,
      group   => $postgres_group,
      mode    => '0750',
      require => Package[$pg_package_name],
   }

   if $doinitdb {
      include pure_postgres::initdb
   }

   file { "${pg_etc_dir}/postgresql.conf":
      ensure    => 'present',
      owner     => $postgres_user,
      group     => $postgres_group,
      mode      => '0640',
      source    => 'puppet:///modules/pure_postgres/postgresql.conf',
      show_diff => false,
      require   => Package[$pg_package_name],
      before    => Class['pure_postgres::start'],
   }
   
}

