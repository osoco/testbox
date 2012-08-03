exec { 'apt-get update':
  command => '/usr/bin/apt-get update'
}

package { "git":
  ensure => present,
}

package { "openjdk-6-jdk":
  require => Exec['apt-get update'],
  ensure => present,
}
