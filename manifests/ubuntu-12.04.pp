import 'params.pp'

Exec { path => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'] }

stage { 
  'init': before => Stage['main'];
}

class {
  'init': stage => 'init';
  'testbox::params': stage => 'init';
  'git_core': stage => 'main';
  'jdk': stage => 'main';
  'grails': stage => 'main';
  'tomcat': stage => 'main';
  'jenkins': stage => 'main';
  'jenkins-plugins': stage => 'main';
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
  package { 'java':
    name => $testbox::params::java_package,
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

  package { 'grails':
    name => "grails-$testbox::params::grails_version",
    ensure => present,
  }

  Exec['grails-apt-get-update'] -> Package['grails']
}

class tomcat {
  package { 'tomcat6':
    ensure => present,
    require => Package['java'],
  }

  exec { "tomcat-home-permissions":
    command => 'chown -R tomcat6:tomcat6 /usr/share/tomcat6',  
    subscribe => Package['tomcat6'],
    refreshonly => true,
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

  exec { 'jenkins-latest-war': 
    command => '/usr/bin/wget --output-document=/var/lib/tomcat6/webapps/jenkins.war http://mirrors.jenkins-ci.org/war/latest/jenkins.war',
    require => [Package['tomcat6'], Exec['tomcat-home-permissions'], Package['wget']],
    creates => '/var/lib/tomcat6/webapps/jenkins.war',
    notify => Service['tomcat6'],
    timeout => 600,
  }
}

class jenkins-plugins {
  package { 'jenkins-cli': 
    ensure => present,
    require => Exec['jenkins-latest-war'],
  }
  
  #exec { 'jenkins-up':
    #require => Exec['jenkins-latest-war'],
    #command => 'wget --spider --tries 10 --retry-connrefused http://localhost:8080/jenkins/',
  #}

  exec { 'jenkins-git-plugin':    
    command => 'jenkins-cli -s http://localhost:8080/jenkins install-plugin http://updates.jenkins-ci.org/download/plugins/git/1.1.24/git.hpi',
    require => Package['jenkins-cli'],
    unless => 'ls /usr/share/tomcat6/.jenkins/plugins/git'
  }

  exec { 'jenkins-grails-plugin':
    command => 'jenkins-cli -s http://localhost:8080/jenkins install-plugin http://mirrors.jenkins-ci.org/plugins/grails/1.6.3/grails.hpi',
    require => Package['jenkins-cli'],
    unless => 'ls /usr/share/tomcat6/.jenkins/plugins/grails'
  }

  exec { 'jenkins-restart':    
    command => 'jenkins-cli -s http://localhost:8080/jenkins restart',
    unless => 'ls /usr/share/tomcat6/.jenkins/plugins/git && ls /usr/share/tomcat6/.jenkins/plugins/grails'
  }
  
  Exec['jenkins-git-plugin'] -> Exec['jenkins-grails-plugin'] -> Exec['jenkins-restart']
}

