output "master_public_ips" {
  value = openstack_networking_floatingip_v2.floatingip_masters.*.address
}

output "master_private_ips" {
  value = openstack_compute_instance_v2.vm_masters.*.network.0.fixed_ip_v4
}

