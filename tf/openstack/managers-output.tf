output "manager_public_ips" {
  value = openstack_networking_floatingip_v2.floatingip_managers.*.address
}

output "manager_private_ips" {
  value = openstack_compute_instance_v2.vm_managers.*.network.0.fixed_ip_v4
}

