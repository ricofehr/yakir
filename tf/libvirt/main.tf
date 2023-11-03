resource "libvirt_pool" "yakir_pool" {
  name = "yakir_pool"
  type = "dir"
  path = var.libvirt_pool_path
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "yakir_os_man_images" {
  count = length(var.yakir_vm_os_man_disks)

  name   = "os-${var.yakir_vm_os_man_disks[count.index]}"
  pool   = libvirt_pool.yakir_pool.name
  source = "${var.yakir_os_img}"
  format = "qcow2"
}

# Define a child volume of OS image with resizing 
resource "libvirt_volume" "yakir_os_man_volumes" {
  count = length(var.yakir_vm_os_man_disks)

  name   = var.yakir_vm_os_man_disks[count.index]
  pool   = libvirt_pool.yakir_pool.name
  base_volume_id  = libvirt_volume.yakir_os_man_images[count.index].id
  size            = var.yakir_vm_os_disk_size 
}

data "template_file" "user_data_man" {
  count = length(var.yakir_vm_man_names)
  template = file("${path.cwd}/cloud_init.cfg")
  vars = {
    hostname = var.yakir_vm_man_names[count.index]
    fqdn = "${var.yakir_vm_man_names[count.index]}.${var.yakir_domain}"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

data "template_cloudinit_config" "config_man" {
  count = length(var.yakir_vm_man_names)
  gzip = false
  base64_encode = false
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = "${data.template_file.user_data_man[count.index].rendered}"
  }
}

data "template_file" "network_config_man" {
  count = length(var.yakir_vm_man_names)
  template = file("${path.cwd}/network_config_dhcp.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit_man" {
  count = length(var.yakir_vm_man_names)
  
  name = "${var.yakir_vm_man_names[count.index]}-commoninit.iso"
  pool   = libvirt_pool.yakir_pool.name
  user_data      = data.template_cloudinit_config.config_man[count.index].rendered
  network_config = data.template_file.network_config_man[count.index].rendered
}

# Create the machine
resource "libvirt_domain" "yakir_man_domains" {
  count = length(var.yakir_vm_man_names)

  name   = var.yakir_vm_man_names[count.index]
  memory = var.yakir_vm_man_ram
  vcpu   = var.yakir_vm_man_cpu
  autostart = true

  network_interface {
    bridge = var.yakir_vm_br_device
    mac   = var.yakir_vm_man_macs[count.index]
    #wait_for_lease = true
  }

  cloudinit = libvirt_cloudinit_disk.commoninit_man[count.index].id

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = lookup(element(libvirt_volume.yakir_os_man_volumes, index(libvirt_volume.yakir_os_man_volumes.*.name, var.yakir_vm_os_man_disks[count.index])), "id")
  }
  
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
  
#  provisioner "remote-exec" {
#    inline = [
#      "cloud-init status --wait",
#    ]
#
#    connection {
#      host     = "${self.network_interface.0.addresses.0}"
#      type     = "ssh"
#      user     = "ubuntu"
#      private_key = "${file("~/.ssh/id_rsa")}"
#    }
#  }
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "yakir_os_wrk_images" {
  count = length(var.yakir_vm_os_wrk_disks)

  name   = "os-${var.yakir_vm_os_wrk_disks[count.index]}"
  pool   = libvirt_pool.yakir_pool.name
  source = "${var.yakir_os_img}"
  format = "qcow2"
}

# Define a child volume of OS image with resizing 
resource "libvirt_volume" "yakir_os_wrk_volumes" {
  count = length(var.yakir_vm_os_wrk_disks)

  name   = var.yakir_vm_os_wrk_disks[count.index]
  pool   = libvirt_pool.yakir_pool.name
  base_volume_id  = libvirt_volume.yakir_os_wrk_images[count.index].id
  size            = var.yakir_vm_os_disk_size
}

# We fetch the latest debian release image from their mirrors
resource "libvirt_volume" "yakir_ceph_wrk_volumes" {
  count = length(var.yakir_vm_ceph_wrk_disks)

  name   = var.yakir_vm_ceph_wrk_disks[count.index]
  pool   = libvirt_pool.yakir_pool.name
  size = var.yakir_vm_ceph_disk_size
  format = "qcow2"
}

data "template_file" "user_data_wrk" {
  count = length(var.yakir_vm_wrk_names)
  template = file("${path.cwd}/cloud_init.cfg")
  vars = {
    hostname = var.yakir_vm_wrk_names[count.index]
    fqdn = "${var.yakir_vm_wrk_names[count.index]}.${var.yakir_domain}"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

data "template_cloudinit_config" "config_wrk" {
  count = length(var.yakir_vm_wrk_names)
  gzip = false
  base64_encode = false
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = "${data.template_file.user_data_wrk[count.index].rendered}"
  }
}

data "template_file" "network_config_wrk" {
  count = length(var.yakir_vm_wrk_names)
  template = file("${path.cwd}/network_config_dhcp.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit_wrk" {
  count = length(var.yakir_vm_wrk_names)
  
  name = "${var.yakir_vm_wrk_names[count.index]}-commoninit.iso"
  pool   = libvirt_pool.yakir_pool.name
  user_data      = data.template_cloudinit_config.config_wrk[count.index].rendered
  network_config = data.template_file.network_config_wrk[count.index].rendered
}

# Create the machine
resource "libvirt_domain" "yakir_wrk_domains" {
  count = length(var.yakir_vm_wrk_names)

  name   = var.yakir_vm_wrk_names[count.index]
  memory = var.yakir_vm_wrk_ram
  vcpu   = var.yakir_vm_wrk_cpu
  autostart = true

  network_interface {
    bridge = var.yakir_vm_br_device
    mac   = var.yakir_vm_wrk_macs[count.index]
    #wait_for_lease = true
  }

  cloudinit = libvirt_cloudinit_disk.commoninit_wrk[count.index].id

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = lookup(element(libvirt_volume.yakir_os_wrk_volumes, index(libvirt_volume.yakir_os_wrk_volumes.*.name, var.yakir_vm_os_wrk_disks[count.index])), "id")
  }
  
  disk {
    volume_id = lookup(element(libvirt_volume.yakir_ceph_wrk_volumes, index(libvirt_volume.yakir_ceph_wrk_volumes.*.name, var.yakir_vm_ceph_wrk_disks[count.index])), "id")
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
  
#  provisioner "remote-exec" {
#    inline = [
#      "cloud-init status --wait",
#    ]
#
#    connection {
#      host     = "${self.network_interface.0.addresses.0}"
#      type     = "ssh"
#      user     = "ubuntu"
#      private_key = "${file("~/.ssh/id_rsa")}"
#    }
#  }
}

