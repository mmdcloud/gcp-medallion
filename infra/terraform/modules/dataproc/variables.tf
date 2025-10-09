variable "cluster_name" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "staging_bucket" {
  type    = string
  default = ""
}

variable "gce_cluster_config" {
  type = object({
    network          = string
    subnetwork       = string
    service_account  = string
    internal_ip_only = bool
    tags             = list(string)
  })
}

variable "master_config" {
  type = object({
    num_instances     = number
    machine_type      = string
    boot_disk_type    = string
    boot_disk_size_gb = number
  })
}

variable "worker_config" {
  type = object({
    num_instances     = number
    machine_type      = string
    boot_disk_type    = string
    boot_disk_size_gb = number
  })
}

variable "software_config" {
  type = object({
    image_version       = string
    optional_components = list(string)
  })
}

variable "autoscaling_policy" {
  type = object({
    name      = string
    policy_id = string
    worker_config = object({
      min_instances = number
      max_instances = number
    })
    yarn_config = object({
      graceful_decommission_timeout = string
      scale_up_factor               = number
      scale_down_factor             = number
    })
    cooldown_period = number
  })
}
