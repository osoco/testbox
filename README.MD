vagrant box add ubuntu-12.04 http://files.vagrantup.com/precise32.box
vagrant init ubuntu-12.04
mkdir manifests
cd manifest
touch ubuntu-12.04.pp
cd ..