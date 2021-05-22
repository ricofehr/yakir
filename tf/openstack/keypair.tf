resource "openstack_compute_keypair_v2" "vm_keypair" {
  name = "${var.keypair_name}"
  public_key = "${var.keypair_sshkey}"
}
