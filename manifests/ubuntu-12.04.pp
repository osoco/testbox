Exec { path => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'] }

stage { 
  'init': before => Stage['main'];
}

class {
  'init': stage => 'init';
  'git_core': stage => 'main';
  'jdk': stage => 'main';
  'grails': stage => 'main';
  'tomcat': stage => 'main';
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

class tomcat {
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
}

class jenkins {
  package { 'wget': 
    ensure => present,
  }

  file { "mkdir-jenkins-home":
    path    => "/var/opt/jenkins",
    mode    => 0755,
    owner   => tomcat6,
    group   => tomcat6,
    ensure  => directory,
    recurse => true,
    require => Package['tomcat6'],
  } 
  
  exec { 'set-jenkins-home-tomcat':
    command => '/bin/echo "JENKINS_HOME=/var/opt/jenkins" >> /etc/default/tomcat6',
    unless => 'grep JENKINS_HOME /etc/default/tomcat6',
  }

  exec { 'jenkins-latest-war':    
    command => '/usr/bin/wget --output-document=/var/lib/tomcat6/webapps/jenkins.war http://mirrors.jenkins-ci.org/war/latest/jenkins.war',
    require => [Package['tomcat6'], Package['wget'], File['mkdir-jenkins-home'], Exec['set-jenkins-home-tomcat']],
    creates => '/var/lib/tomcat6/webapps/jenkins.war',
    notify => Service['tomcat6'],
    timeout => 600,
  }
}

