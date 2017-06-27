# Copyright (C) 2017 Collaboration of KPN and Splendid Data
#
# This file is part of puppet_pure_postgres.
#
# puppet_pure_barman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# puppet_pure_postgres is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with puppet_pure_postgres.  If not, see <http://www.gnu.org/licenses/>.

# == Class: pure_postgres::config::ssh
#
# Configure a replicated cluster with repmgr from pure repo 
class pure_postgres::config::ssh
(
  $tags = undefined,
)
{

  @@sshkey { $facts['fqdn']:
    type => ecdsa-sha2-nistp256,
    key  => $::sshecdsakey,
    tag  => $tags,
  }

  @@sshkey { "${facts['fqdn']}_${facts['networking']['ip']}":
    name => $facts['networking']['ip'],
    type => ecdsa-sha2-nistp256,
    key  => $::sshecdsakey,
    tag  => $tags,
  }

  if $facts['fqdn'] != $facts['hostname'] {
    @@sshkey { "${facts['fqdn']}_${facts['hostname']}":
      name => $facts['hostname'],
      type => ecdsa-sha2-nistp256,
      key  => $::sshecdsakey,
      tag  => $tags,
    }
  }

  $tags.each | $tag | {
    if $tag!=undef {
      Sshkey <<| tag == $tag |>>
    }
  }
}

