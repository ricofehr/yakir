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

variable "flavor_master" {
  description = "Flavor to use with k8s-master vm"
  default = "large"
}

variable "flavor_node" {
  description = "Flavor to use with k8s-node vms"
  default = "xlarge"
}

variable "private_network_name" {
  description = "Openstack private internal network name"
  default = "private"
}

variable "public_network_name" {
  description = "Openstack provider external network name (floating ips)"
  default = "public"
}

variable "security_group" {
  description = "Openstack security group"
  default = "k8s"
}

variable "image" {
  description = "OS-Image Name to use with k8s vms"
  default = "bionic"
}

variable "keypair_sshkey" {
  description = "Rsa ssh key, no default value"
}
