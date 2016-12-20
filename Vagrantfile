# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

proj_dir = File.basename(Dir.pwd)
ENV["LC_ALL"] = "en_US.UTF-8"
vm_ip = "192.168.100.16"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
	## Choose your base box
	config.vm.box = "ubuntu/trusty64"
	
  ## Configure some networking stuff on the guest VM
  config.vm.host_name = "#{proj_dir}"
  config.vm.network "private_network", ip: "#{vm_ip}"
    
  ## Don't insert a brand new SSH key. Just use the default insecure_private_key.
  config.ssh.insert_key = false
    
  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 2
  end
	
	## For masterless, mount your salt file root
	config.vm.synced_folder "./", "/home/vagrant/#{proj_dir}"
	
	config.vm.provision "fix-no-tty", type: "shell" do |s|
		s.privileged = false
		s.inline = "sudo sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile"
	end
	
	#config.vm.provision "shell" do |s|
  #  s.inline = "cd #{proj_dir};salt-provision/run.sh -B '-M'"
  #  s.keep_color = false
  #end

end
