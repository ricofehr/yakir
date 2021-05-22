# Define required providers
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.42.0"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  user_name   = "${var.provider_user}"
  tenant_name = "${var.provider_tenant}"
  password    = "${var.provider_password}"
  auth_url    = "${var.provider_auth_url}"
  region      = "${var.provider_region}"
  user_domain_name = "Default"
  project_domain_name = "Default"
  endpoint_type = "internalURL"
  insecure = true
}


