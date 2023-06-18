variable "provider_user" {
  description = "The username of the openstack intall"
  default = "tenant0"
}

variable "provider_tenant" {
  description = "The tenant of the openstack install"
  default = "tenant0"
}

variable "provider_password" {
  description = "The tenant of the openstack install"
  default = "tenant0"
}

variable "provider_auth_url" {
  description = "The auth url of the openstack install"
  default = "http://172.29.236.101:5000/v3"
}

variable "provider_region" {
  description = "The region of the openstack install"
  default = "RegionOne"
}

variable "keypair_name" {
  description = "SSH keypair name"
  default = "k8s-keypair"
}

variable "keypair_sshkey" {
  description = "Public SSH keypair content"
}

variable "public_network_name" {
  description = "External openstack network name"
  default = "public"
}

variable "private_network_name" {
  description = "Internal openstack network name"
  default = "private"
}

variable "private_network_id" {
  description = "Internal openstack network id"
}

variable "private_subnet_id" {
  description = "Internal openstack subnet id"
}

variable "vip_managers_ip" {
  description = "VIP IP for managers node"
}

variable "image" {
  description      = "OS Glance Image"
  default = "focal"
}

variable "security_group" {
  description      = "Openstack security group"
  default          = "k8s"
}

variable "k8s_manager_name" {
  description      = "Vm names"
  default = "k8s-manager"
}

variable "k8s_node_name" {
  description      = "Vm names"
  default = "k8s-node"
}

variable "k8s_manager_flavor" {
  description      = "Vm Sizing Label"
  default = "large"
}

variable "k8s_node_flavor" {
  description      = "Vm Sizing Label"
  default = "xlarge"
}

