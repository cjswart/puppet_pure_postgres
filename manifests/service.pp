# == Class: pure_postgres::service
#
# Manages service of postgres installed from pure repo

class pure_postgres::service
(
)
{

  include pure_postgres::start

  include pure_postgres::restart

  include pure_postgres::reload

}

