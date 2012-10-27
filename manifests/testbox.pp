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
  'jenkins-config': stage => 'main';
  'jenkins-plugins': stage => 'main';
  'jenkins-plugins-config': stage => 'main';
  'jenkins-job': stage => 'main';
  'firefox-headless': stage => 'main';
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

  package { 'sed': 
    ensure => present,
  }

  package { 'tomcat6':
    ensure => present,
    require => Package['java'],
  }

  exec { 'tomcat-home-permissions':
    command => "chown -R tomcat6:tomcat6 $tomcat_home",  
    subscribe => Package['tomcat6'],
    refreshonly => true,
  }

  exec { 'non-conflicting-tomcat-port':
    command => "sed -i -e 's/8080/8888/g' /etc/tomcat6/server.xml",
    require => [Package['sed'], Package['tomcat6']],
    unless => 'grep 8888 /etc/tomcat6/server.xml',
  }

  exec { 'tomcat6':
    command => '/etc/init.d/tomcat6 restart',
    subscribe => Exec['non-conflicting-tomcat-port'],
    refreshonly => true,
  }
}

class jenkins {
  $jenkins_home = '/usr/share/tomcat6/.jenkins'
  $jenkins_url = 'http://localhost:8888/jenkins/'

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
    require => [Exec['tomcat6'], Exec['tomcat-home-permissions'], Exec['jenkins-download']],
  }

  package { 'jenkins-cli': 
    ensure => present,
    require => Exec['jenkins-deploy'],
  }

  exec { 'jenkins-up':
    command => "wget --spider $jenkins_url",
    tries => 30,
    try_sleep => 1,
    require => Exec['jenkins-deploy'],
    unless => "wget --spider --tries=1 $jenkins_url",
  }
}

class jenkins-config {
  file { "$jenkins::jenkins_home/config.xml":
    mode => '0644',
    owner => 'vagrant',
    group => 'vagrant',
    source => "puppet:///modules/config/config.xml",
    ensure => present,
    require => Exec['jenkins-up'],
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

  exec { 'jenkins-xvfb-plugin':
    command => "jenkins-cli -s $jenkins::jenkins_url install-plugin http://mirrors.jenkins-ci.org/plugins/xvfb/1.0.4/xvfb.hpi",
    require => [Package['jenkins-cli'], Exec['jenkins-up']],
    unless => "ls $jenkins::jenkins_home/plugins/xvfb",
  }

  exec { 'jenkins-restart':    
    command => "jenkins-cli -s $jenkins::jenkins_url restart",
    unless => "ls $jenkins::jenkins_home/plugins/git && ls $jenkins::jenkins_home/plugins/grails && ls $jenkins::jenkins_home/plugins/xvfb",
    require => [Exec['jenkins-git-plugin'], Exec['jenkins-grails-plugin'], Exec['jenkins-xvfb-plugin']]
  }
  
  exec { 'jenkins-restarted':    
    command => "jenkins-cli -s $jenkins::jenkins_url version",
    tries => 30,
    try_sleep => 1,
    require => Exec['jenkins-restart'],
    unless => "jenkins-cli -s $jenkins::jenkins_url version",
  }
}

class jenkins-plugins-config {
  file { "$jenkins::jenkins_home/org.jenkinsci.plugins.xvfb.XvfbBuildWrapper.xml":
    mode => '0644',
    owner => 'vagrant',
    group => 'vagrant',
    source => "puppet:///modules/config/org.jenkinsci.plugins.xvfb.XvfbBuildWrapper.xml",
    ensure => present,
    require => Exec['jenkins-xvfb-plugin'],
  }
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
    require => [File['job-config.xml'], Exec['jenkins-restarted']],
    unless => "ls $jenkins::jenkins_home/jobs/$job_name",
  }

  exec { 'jenkins-start-job':
    command => "jenkins-cli -s $jenkins::jenkins_url build $job_name",
    require => Exec['jenkins-create-job'],
  }
}

class firefox-headless {
  package { 'firefox': 
    ensure => present,
  }

  package { 'xvfb': 
    ensure => present,
  }

  package { 'xfonts-base': 
    ensure => present,
  }

  package { 'xfonts-75dpi': 
    ensure => present,
  }

  package { 'xfonts-100dpi': 
    ensure => present,
  }
}

