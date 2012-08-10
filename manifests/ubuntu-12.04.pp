Exec { path => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'] }

include rvm

stage { 
  'init': before => Stage['rvm-install', 'main'];
}

class {
  'init': stage => 'init';
  'jdk': stage => 'main';
  'grails': stage => 'main';
  'git_core': stage => 'main';
  'goldberg': stage => 'main';
}  

class init {
  exec { 'initial-apt-get-update':
    command => 'apt-get update',
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
  }

  exec { 'apt-get-update':
    command => 'apt-get update',
  }

  package { 'grails-1.3.7':
    ensure => present,
  }

  Exec['ppa:groovy-dev/grails'] -> Exec['apt-get-update'] -> Package['grails-1.3.7']
}

class goldberg {
  exec { 'goldberg-clone-repo':
    command => 'git clone git://github.com/c42/goldberg.git',
    creates => '/home/vagrant/goldberg',
    user => 'vagrant',
  }

  rvm_system_ruby {
    'ruby-1.9.3-p194':
       ensure => 'present',
       default_use => false;
  }                      

}
