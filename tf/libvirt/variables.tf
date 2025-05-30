variable "provider_uri" {
  description = "KVM hypervisor URI"
  default = "qemu:///system"
}

variable "libvirt_pool_path" {
  description = "Volume Pool storage"
  default = "/opt/libvirt/kvm/pool"
}

variable "yakir_domain" {
  description = "Network domain"
  default = "k8s.local"
}

variable "yakir_vm_os_man_disks" {
  description = "Linux Image Names"
  default = ["k8s-man-01-os-disk", "k8s-man-02-os-disk", "k8s-man-03-os-disk", "k8s-wrk-01-os-disk", "k8s-wrk-02-os-disk"]
}

variable "yakir_vm_os_wrk_disks" {
  description = "Linux Image Names"
  default = ["k8s-man-01-os-disk", "k8s-man-02-os-disk", "k8s-man-03-os-disk", "k8s-wrk-01-os-disk", "k8s-wrk-02-os-disk"]
}

variable "yakir_vm_ceph_wrk_disks" {
  description = "Ceph Image Names"
  default = ["k8s-man-01-ceph-disk", "k8s-man-02-ceph-disk", "k8s-man-03-ceph-disk", "k8s-wrk-01-ceph-disk", "k8s-wrk-02-ceph-disk"]
}

variable "yakir_os_img" {
  description = "Ubuntu kvm img url"
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64-disk-kvm.img"
}

variable "yakir_vm_man_names" {
  description      = "Yakir Manager Vm names"
  default = ["k8s-man-01", "k8s-man-02", "k8s-man-03"]
}

variable "yakir_vm_wrk_names" {
  description      = "Yakir Worker Vm names"
  default = ["k8s-wrk-01", "k8s-wrk-02"]
}

variable "yakir_vm_os_disk_size" {
  description      = "Linux disk size (default is 10Go)"
  default = 10737418240
}

variable "yakir_vm_ceph_disk_size" {
  description      = "Ceph disk size for each worker node (default is 100Go)"
  default = 107374182400
}

variable "yakir_vm_man_ram" {
  description      = "Yakir Manager  Vm RAM"
  default = 2048
}

variable "yakir_vm_wrk_ram" {
  description      = "Yakir Worker Vm RAM"
  default = 4096
}

variable "yakir_vm_man_cpu" {
  description      = "Yakir Manager Vm CPU"
  default = 2
}

variable "yakir_vm_wrk_cpu" {
  description      = "Yakir Worker Vm CPU"
  default = 4
}

variable "yakir_vm_br_device" {
  description      = "Yakir Vm Bridge"
  default = "bridge"
}

variable "yakir_vm_man_macs" {
  description      = "Yakir Vm Mac"
  default = ["24:41:00:a3:f4:21", "24:41:00:c6:35:14", "24:41:00:2b:89:78"]
}

variable "yakir_vm_wrk_macs" {
  description      = "Yakir Vm Mac"
  default = ["24:41:00:78:9a:57", "24:41:00:17:83:2f"]
}
