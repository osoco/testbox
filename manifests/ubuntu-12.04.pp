Exec { path => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'] }

stage { 
  'init': before => Stage['main'];
}

class {
  'init': stage => 'init';
  'jdk': stage => 'main';
  'grails': stage => 'main';
  'git_core': stage => 'main';
  'jenkins': stage => 'main';
}  

class init {
  exec { 'initial-apt-get-update':
    command => 'apt-get update',
    onlyif => "/bin/sh -c '[ ! -f /var/cache/apt/pkgcache.bin ] || /usr/bin/find /etc/apt/* -cnewer /var/cache/apt/pkgcache.bin | /bin/grep . > /dev/null'",
  }

  package { 'python-software-properties':
    ensure => present,
  }
  
  Exec['initial-apt-get-update'] -> Package['python-software-properties']
}

class git_core { 
	package { 'git':
        ensure => present,
    }
}

class jdk {
  package { "openjdk-6-jdk":
    ensure => present,
  }
}

class grails {
  exec { 'ppa:groovy-dev/grails':
    command => 'add-apt-repository ppa:groovy-dev/grails',
    unless => 'ls /etc/apt/sources.list.d/groovy-dev-grails-*',
  }

  exec { 'grails-apt-get-update':
    command => 'apt-get update',
    subscribe => Exec['ppa:groovy-dev/grails'],
    refreshonly => true,
  }

  package { 'grails-1.3.7':
    ensure => present,
  }

  Exec['grails-apt-get-update'] -> Package['grails-1.3.7']
}

class jenkins {
  package { 'wget': 
    ensure => present,
  }

  package { 'sed': 
    ensure => present,
  }

  package { 'tomcat6':
    ensure => present,
    require => Package['openjdk-6-jdk'],
  }

  service { 'tomcat6':
    ensure => running,
    require => Package['tomcat6'],
  }

  exec { 'jenkins-latest-war':
    command => '/usr/bin/wget --output-document=/var/lib/tomcat6/webapps/jenkins.war http://mirrors.jenkins-ci.org/war/latest/jenkins.war',
    require => Package['tomcat6'],
    creates => '/var/lib/tomcat6/webapps/jenkins.war',
    timeout => 600,
  }

  exec { 'non-conflicting-tomcat-port':
    command => "sed -i -e 's/8080/8888/g' /etc/tomcat6/server.xml",
    notify => Service['tomcat6'],
    unless => 'grep 8888 /etc/tomcat6/server.xml',
  }
}

