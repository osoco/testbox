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
  'jenkins-job': stage => 'main';
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
  $tomcat_home = '/usr/share/tomcat6'
  $tomcat_webapps = '/var/lib/tomcat6/webapps'

  package { 'tomcat6':
    ensure => present,
    require => Package['java'],
  }

  exec { 'tomcat-home-permissions':
    command => "chown -R tomcat6:tomcat6 $tomcat_home",  
    subscribe => Package['tomcat6'],
    refreshonly => true,
  }

  service { 'tomcat6':
    ensure => running,
    require => Package['tomcat6'],
  }
}

class jenkins {
  $jenkins_home = '/usr/share/tomcat6/.jenkins'
  $jenkins_url = 'http://localhost:8080/jenkins/'

  package { 'wget': 
    ensure => present,
  }

  exec { 'jenkins-download': 
    command => 'wget --output-document=/tmp/jenkins.war http://mirrors.jenkins-ci.org/war/latest/jenkins.war',
    require => Package['wget'],
    creates => "$tomcat::tomcat_webapps/jenkins.war",
    timeout => 600,
  }

  exec { 'jenkins-deploy': 
    command => "mv /tmp/jenkins.war $tomcat::tomcat_webapps/jenkins.war",
    creates => "$tomcat::tomcat_webapps/jenkins.war",
    require => [Package['tomcat6'], Exec['tomcat-home-permissions'], Exec['jenkins-download']],
  }

  package { 'jenkins-cli': 
    ensure => present,
    require => Exec['jenkins-deploy'],
  }

  exec { 'jenkins-up':
    command => "bash -c 'max=30; while ! wget --spider $jenkins_url > /dev/null 2>&1; do max=\$((max - 1)); [ \$max -lt 0 ] && break; sleep 1; done; [ \$max -gt 0 ]'",
    require => Exec['jenkins-deploy'],
    unless => "wget --spider --tries=1 $jenkins_url",
  }
}

class jenkins-plugins {
  exec { 'jenkins-git-plugin':    
    command => "jenkins-cli -s $jenkins::jenkins_url install-plugin http://updates.jenkins-ci.org/download/plugins/git/1.1.24/git.hpi",
    require => [Package['jenkins-cli'], Exec['jenkins-up']],
    unless => "ls $jenkins::jenkins_home/plugins/git",
  }

  exec { 'jenkins-grails-plugin':
    command => "jenkins-cli -s $jenkins::jenkins_url install-plugin http://mirrors.jenkins-ci.org/plugins/grails/1.6.3/grails.hpi",
    require => [Package['jenkins-cli'], Exec['jenkins-up']],
    unless => "ls $jenkins::jenkins_home/plugins/grails",
  }

  exec { 'jenkins-restart':    
    command => "jenkins-cli -s $jenkins::jenkins_url restart",
    unless => "ls $jenkins::jenkins_home/plugins/git && ls $jenkins::jenkins_home/plugins/grails",
  }
  
  Exec['jenkins-git-plugin'] -> Exec['jenkins-grails-plugin'] -> Exec['jenkins-restart']
}

class jenkins-job {
  $project_repository_url = $testbox::params::project_repository_url
  $job_config = '/home/vagrant/job-config.xml'
  $job_name = $testbox::params::job_name

  file { 'job-config.xml':
    path => $job_config,
    mode => '0644',
    owner => 'vagrant',
    group => 'vagrant',
    content => template('config/config.erb'),
    ensure => present,
    require => Exec['jenkins-deploy'],
  }

  exec { 'jenkins-create-job':
    command => "jenkins-cli -s $jenkins::jenkins_url create-job $job_name < $job_config",
    require => [File['job-config.xml'], Package['jenkins-cli'], Exec['jenkins-restart']],
    unless => "ls $jenkins::jenkins_home/jobs/$job_name",
  }
}
