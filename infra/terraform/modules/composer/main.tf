resource "google_composer_environment" "composer_env" {
  name   = var.composer_name
  region = var.region
  config {    
    # Airflow settings
    software_config {
      image_version = var.software_config.image_version
      python_version = var.software_config.python_version
      # Optional: Pypi packages
      pypi_packages = var.software_config.pypi_packages
      # Optional: environment variables
      env_variables = var.software_config.env_variables
    }
    # Node configuration
    node_config {
      machine_type    = var.node_config.machine_type
      network         = var.node_config.network
      subnetwork      = var.node_config.subnetwork
      service_account = var.node_config.service_account
      disk_size_gb    = var.node_config.disk_size_gb
    }
    # High Availability
    private_environment_config {      
      master_ipv4_cidr_block    = "10.10.0.0/28"
      web_server_ipv4_cidr_block = "10.10.1.0/28"
    }    
  }
}