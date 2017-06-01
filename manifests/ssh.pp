# == Class: pure_postgres::ssh
#
# Configure a replicated cluster with repmgr from pure repo 
class pure_postgres::ssh
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

