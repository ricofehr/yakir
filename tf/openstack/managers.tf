resource "openstack_networking_floatingip_v2" "floatingip_managers" {
  pool = "${var.public_network_name}"
  count = var.k8s_managers
}

resource "openstack_networking_port_v2" "port_managers" {
  name           = "port-managers-${count.index + 1}"
  network_id     = var.private_network_id
  admin_state_up = true
  fixed_ip {
    subnet_id = var.private_subnet_id
  }
  allowed_address_pairs {
    ip_address = var.vip_managers_ip
  }
  count = var.k8s_managers
}

resource "openstack_compute_instance_v2" "vm_managers" {
  name            = "${var.k8s_manager_name}${count.index + 1}"
  image_name      = "${var.image}"
  flavor_name     = "${var.k8s_manager_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.vm_keypair.name}"
  security_groups = ["${var.security_group}"]

  network {
    port = openstack_networking_port_v2.port_managers[count.index].id
  }
  count = var.k8s_managers
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_binding_managers" {
  floating_ip = "${openstack_networking_floatingip_v2.floatingip_managers[count.index].address}"
  instance_id = "${openstack_compute_instance_v2.vm_managers[count.index].id}"
  count = var.k8s_managers
}
