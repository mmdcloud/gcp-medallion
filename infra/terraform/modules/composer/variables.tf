variable "composer_name" {
  type    = string
  default = ""  
}

variable "region" {
  type    = string
  default = ""  
}

variable "software_config" {
  type = object({
    image_version = string
    python_version = string
    pypi_packages = map(string)
    env_variables = map(string)
  })  
}

variable "node_config" {
  type = object({
    machine_type    = string
    network         = string
    subnetwork      = string
    service_account = string
    disk_size_gb    = number
  }) 
}