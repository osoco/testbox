# What is testbox?
Testbox is a personal test execution server. It's simply a Jenkins server hosted in a VirtualBox virtual machine that listens to local Git repository commits and executes all tests defined in the project.

It is configured out-of-the-box for Grails and Git projects, but it can be tweaked to execute builds of any project type.

# Why testbox?
Your are using Git for your daily Grails work. You have a lot of tests at different levels (unit, integration and of course functional). Before pushing the project (and executing the tests in your central CI server) you run all the tests locally to see if nothing is broken. This is time consuming and interrupts your work. And these annoying browser windows popping up on every Selenium testcase…

Testbox allows you to continue working on your code while tests are being executed. You simply commit to the local Git repository and testbox starts executing tests of the codebase defined this commit. If the tests fail, you can simply amend that commit and testbox will execute them once again. Browser based tests are supported too, since it providers a virtual X11 server (Xvfb).

Testbox is based on Vagrant. Vagrant allows you to create developer virtual machines provisioning them with [Puppet](http://puppetlabs.com/) or [Chef](http://www.opscode.com/chef/) 

# Installation
* Install the latest version of Vagrant and the Vagrant compatible version of VirtualBox as described in _Get VirtualBox_ and _Install Vagrant_ sections of the [installation manual](http://vagrantup.com/v1/docs/getting-started/).
* Download the base box (pre-packaged virtual machine in then Vagrant jargon) based on Ubuntu 12.04:

```
vagrant box add ubuntu-12.04 http://files.vagrantup.com/precise32.box
```
* Clone this repository to a local directory (refered futher as ``TESTBOX_HOME``):

```
git clone https://github.com/osoco/testbox TESTBOX_HOME
```
* Configure the initial box parameters, editing ``TESTBOX_HOME/manifests/params.pp``:
  * ``grails_version`` - Grails Ubuntu package version available in ``ppa:groovy-dev/grails``
  * ``java_package`` - Java Ubuntu package; currently Ubuntu provides OpenJDK 6 and 7 as ``openjdk-6-jdk`` and ``openjdk-7-jdk`` packages
  * ``project_repository_url`` - path to the local Git repository; refer to the [host file system access](#host_file_system_access) section to check how the host file system is accessible from the virtual machine. Example: ``/home/mgryszko/testbox-sample-app``
  * ``job_name`` - Jenkins job name created during provisioning
* Power up the virtual machine and start provisioning. In ``TESTBOX_HOME`` execute:

```
vagrant up
```
Watch the progress and be patient, it takes some time to finish.

* If you get an error described in the [Troubleshooting](#heap_size_error) section, set the ``JAVA_OPTS`` environment variable in Jenkins global configuration (Go to _Jenkins/Manage Jenkins/Configure system_) 
* If your application is memory consuming, increase the virtual machine RAM and set the ```GRAILS_OPTS``` environment variable as described in the [memory-hungry applications](#memory_hungry_applications) section

# Usage
## SSH login
```
vagrant ssh
```
no user/password required,

## sudo
Simply ``sudo``, no password required.

## testbox user/password
``vagrant``/``vagrant``

## [host file system access](id:host_file_system_access)
Testbox shares your home directory with the virtual machine under ``/home/$USER``, where ``$USER`` refers to the user name on the host machine.

On MacOSX host, the home directory ``/Users/mgryszko`` is shared as ``/home/mgryszko`` in the virtual machine. On Linux host the mapping is 1:1 - ``/home/mgryszko`` on host becomes ``/home/mgryszko`` in the VM.

## [network](id:network)
### virtual machine -> host

Host network is bridged to the virtual machine. This means you have full access to the network the host is connected to from the guest. More on this in the [VirtualBox manual](http://www.virtualbox.org/manual/ch06.html).
### host -> virtual machine
Virtual machine port ``8888`` is mapped to ``8888`` local port.

## Jenkins access
Jenkins runs on ``8888`` port inside the virtual machine. As explained in the [network](#network) section, you can access Jenkins by opening this URL in your browser:

```
http://localhost:8888
```

## [memory-hungry applications](id:memory_hungry_applications)
* Increase virtual machine RAM. Stop the testbox. Open VirtualBox application. In VM settings increase the available RAM size going to the _System_ tab.
* Set ``GRAILS_OPTS`` environment variable in _Jenkins/Manage Jenkins/Configure system_, e.g. to ``-Xms512M -Xmx1024M -XX:PermSize=256M -XX:MaxPermSize=256M``
* Allocate more memory to the virtual machine (via VirtualBox configuration) than to JVM!

## testbox startup/shutdown
Startup:

```
vagrant up
```

Shutdown:

```
vagrant halt
```

# Troubleshooting
## [Build error _Incompatible minimum and maximum heap sizes specified_](id:heap_size_error)
If you get the following error message at the very beginning of your build:

```
Incompatible minimum and maximum heap sizes specified
Error occurred during initialization of VM
Build step 'Build With Grails' marked build as failure
```
### Solution
Set the ``JAVA_OPTS`` environment variable for Jenkins. In _Jenkins/Manage Jenkins/Configure system_, Global properties section, add a new environment variable with:

* name: ``JAVA_OPTS``
* value: ``-Xms4M -Xmx64M``

## Git doesn't clone the repository
### Solution
Check your project directory permissions. The project and Git directory on the host must be available (readable) to Jenkins user (tomcat6). In practice it means that your project directory should allow read access to others.

# Compatibility
Testbox was tested on MacOSX 10.7 and 10.8. It should work on any Linux distribution where Vagrant is supported.

