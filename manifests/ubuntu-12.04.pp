class git {
  exec { 'apt-get update':
    command => '/usr/bin/apt-get update'
  }

  package { "git":
    ensure => present,
  }
}

include git