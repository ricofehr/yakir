resource "openstack_networking_floatingip_v2" "floatingip_masters" {
  pool = "${var.public_network_name}"
  count = var.k8s_masters
}

resource "openstack_networking_port_v2" "port_masters" {
  name           = "port-masters-${count.index + 1}"
  network_id     = var.private_network_id
  admin_state_up = true
  fixed_ip {
    subnet_id = var.private_subnet_id
  }
  allowed_address_pairs {
    ip_address = var.vip_managers_ip
  }
  count = var.k8s_masters
}

resource "openstack_compute_instance_v2" "vm_masters" {
  name            = "${var.k8s_master_name}${count.index + 1}"
  image_name      = "${var.image}"
  flavor_name     = "${var.k8s_master_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.vm_keypair.name}"
  security_groups = ["${var.security_group}"]

  network {
    port = openstack_networking_port_v2.port_masters[count.index].id
  }
  count = var.k8s_masters
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_binding_masters" {
  floating_ip = "${openstack_networking_floatingip_v2.floatingip_masters[count.index].address}"
  instance_id = "${openstack_compute_instance_v2.vm_masters[count.index].id}"
  count = var.k8s_masters
}
