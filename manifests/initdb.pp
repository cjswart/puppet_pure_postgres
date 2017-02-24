# == Class: pure_postgres::initdb
#
# Module for initing a new postgres cluster
class pure_postgres::initdb
(
) inherits pure_postgres
{

   $initcmd = shellquote("${pg_bin_dir}/initdb", "-D", $pg_data_dir, '-E', $pg_encoding )

   if $pg_xlog_dir != "$pg_data_dir/pg_xlog" {
      $xlogcmd = shellquote( "-X", $pg_xlog_dir )
   }

   exec { "initdb ${pg_data_dir}":
      user     => $postgres_user,
      command  => "$initcmd $xlogcmd",
      creates  => "${pg_data_dir}/PG_VERSION",
      cwd      => $pg_bin_dir,
      require  => [ Package[$pg_package_name], File[$pg_xlog_dir], File[$pg_data_dir] ],
   } ->

   exec { "move ${pg_etc_dir}/pg_hba.conf":
      user     => $postgres_user,
      command  => "/bin/mv '${pg_data_dir}/pg_hba.conf' ${pg_etc_dir}/pg_hba.conf",
      unless   => "/bin/test -s '${pg_etc_dir}/pg_hba.conf'",
      cwd      => $pg_bin_dir,
   }

   file { "${pg_data_dir}/pg_hba.conf":
      ensure  => 'absent',
      require => Exec["move ${pg_etc_dir}/pg_hba.conf"],
   }

   exec { "move ${pg_etc_dir}/pg_ident.conf":
      user     => $postgres_user,
      command  => "/bin/mv '${pg_data_dir}/pg_ident.conf' ${pg_etc_dir}/pg_ident.conf",
      unless   => "/bin/test -s '${pg_etc_dir}/pg_ident.conf'",
      cwd      => $pg_bin_dir,
   }

   file { "${pg_data_dir}/pg_ident.conf":
      ensure  => 'absent',
      require => Exec["move ${pg_etc_dir}/pg_ident.conf"],
   }

   #Add conf.d to postgres.conf
   file_line { 'confd':
      path    => "$pg_etc_dir/postgresql.conf",
      line    => "include_dir = 'conf.d'",
      require => File["${pg_etc_dir}/postgresql.conf"],
   }

   file { "${pg_etc_dir}/conf.d/defaults.conf":
      ensure   => 'present',
      owner    => $postgres_user,
      group    => $postgres_group,
      mode     => '0640',
      replace  => false,
      source  => 'puppet:///modules/pure_postgres/defaults.conf',
      require  => File["${pg_etc_dir}/conf.d"],
   }

   file { "${pg_data_dir}/postgresql.conf":
      ensure  => 'absent',
   }

}

