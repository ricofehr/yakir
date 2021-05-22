output "node_public_ips" {
  value = openstack_networking_floatingip_v2.floatingip_nodes.*.address
}

output "node_private_ips" {
  value = openstack_compute_instance_v2.vm_nodes.*.network.0.fixed_ip_v4
}

