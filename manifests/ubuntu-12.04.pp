stage { 'init': before => Stage['main'] }

class {
  'init': stage => 'init',
}  

class init {
  exec { 'initial-apt-get-update':
    command => '/usr/bin/apt-get update',
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

define git::clone($path) {
    include git_core
    exec { 'git clone':
        command => "/usr/bin/git clone $path /home/vagrant/RMB-BACKOFFICE-BMS"
    }
}

git::clone { 'git clone repo':
	path => '/home/dmcom/Documents/osoco/rumbo/bms/RMB-BACKOFFICE-BMS',
}

class jdk {
  package { "openjdk-6-jdk":
    ensure => present,
  }
}

class grails {
  exec { 'ppa:groovy-dev/grails':
    command => '/usr/bin/add-apt-repository ppa:groovy-dev/grails',
  }

  exec { 'apt-get-update':
    command => '/usr/bin/apt-get update',
}

  package { 'grails-1.3.7':
    ensure => present,
  }

  Exec['ppa:groovy-dev/grails'] -> Exec['apt-get-update'] -> Package['grails-1.3.7']
}
