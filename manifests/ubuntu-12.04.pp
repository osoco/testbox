class git_core { 
	exec { 'apt-get update':
		command => '/usr/bin/apt-get update'
	}

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