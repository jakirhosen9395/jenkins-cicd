# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "alvistack/ubuntu-24.04"

  # Jenkins Server
  config.vm.define "jenkins" do |node|
    node.vm.hostname = "jenkins-server"
    node.vm.network "private_network", ip: "192.168.56.50"

    node.vm.provider "libvirt" do |lv|
      lv.memory = 4096   # 4 GB for Jenkins
      lv.cpus   = 4
    end
  end

  # Deployment Server
  config.vm.define "deployment" do |node|
    node.vm.hostname = "deployment-server"
    node.vm.network "private_network", ip: "192.168.56.51"

    node.vm.provider "libvirt" do |lv|
      lv.memory = 2048   # 2 GB for Deployment
      lv.cpus   = 2
    end
  end
end

