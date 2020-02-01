# k8s master
masters = {
    "k8s-master1" => "192.168.78.10"
}

# k8s nodes
nodes = {
    "k8s-node1" => "192.168.78.20",
    "k8s-node2" => "192.168.78.21",
    "k8s-node3" => "192.168.78.22",
    "k8s-node4" => "192.168.78.23",
    "k8s-node5" => "192.168.78.24"
}

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false
    config.ssh.forward_agent = true

    check_guest_additions = false
    functional_vboxsf = false

    config.vm.box = "bento/ubuntu-18.04"

    masters.each do |name, ip|
      config.vm.define name do |machine|
        machine.vm.hostname = name
        machine.vm.network :private_network, ip: ip
        machine.vm.provider :virtualbox do |v|
          v.name = name
          v.memory = 4096
          v.cpus = 2
        end
      end
    end

    nodes.each do |name, ip|
      config.vm.define name do |machine|
        machine.vm.hostname = name
        machine.vm.network :private_network, ip: ip
        machine.vm.provider :virtualbox do |v|
          v.name = name
          v.memory = 5120
          v.cpus = 4
        end

        if name == "k8s-node5"
          machine.vm.provision "ansible" do |ansible|
            ansible.playbook = "ansible/playbook.yml"
            ansible.inventory_path = "ansible/inventory"
            ansible.extra_vars = { global_ci_install: "#{ENV['CI_INSTALL']}" }
            ansible.verbose = false
            ansible.limit = "all"
          end
        end
      end
    end
end
