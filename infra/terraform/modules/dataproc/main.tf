resource "google_dataproc_autoscaling_policy" "autoscaling_policy" {
  name      = var.autoscaling_policy.name
  policy_id = var.autoscaling_policy.policy_id
  basic_algorithm {
    cooldown_period = var.autoscaling_policy.cooldown_period
    yarn_config {
      graceful_decommission_timeout = var.autoscaling_policy.yarn_config.graceful_decommission_timeout
      scale_up_factor               = var.autoscaling_policy.yarn_config.scale_up_factor
      scale_down_factor             = var.autoscaling_policy.yarn_config.scale_down_factor
    }
  }
  worker_config {
    min_instances = var.autoscaling_policy.worker_config.min_instances
    max_instances = var.autoscaling_policy.worker_config.max_instances
  }
}

resource "google_dataproc_cluster" "cluster" {
  name   = var.cluster_name
  region = var.region
  cluster_config {
    staging_bucket = var.staging_bucket
    gce_cluster_config {
      network          = var.gce_cluster_config.network
      subnetwork       = var.gce_cluster_config.subnetwork
      service_account  = var.gce_cluster_config.service_account
      internal_ip_only = var.gce_cluster_config.internal_ip_only
      tags             = var.gce_cluster_config.tags
    }
    master_config {
      num_instances = var.master_config.num_instances
      machine_type  = var.master_config.machine_type
      disk_config {
        boot_disk_type    = var.master_config.boot_disk_type
        boot_disk_size_gb = var.master_config.boot_disk_size_gb
      }
    }
    worker_config {
      num_instances = var.worker_config.num_instances
      machine_type  = var.worker_config.machine_type
      disk_config {
        boot_disk_type    = var.worker_config.boot_disk_type
        boot_disk_size_gb = var.worker_config.boot_disk_size_gb
      }
    }    
    software_config {
      image_version       = var.software_config.image_version
      optional_components = var.software_config.optional_components
    }
    autoscaling_config {
      policy_uri = google_dataproc_autoscaling_policy.autoscaling_policy.id
    }
    # encryption_config {
    #   kms_key_name = var.kms_key_name
    # }
  }
  labels = {
    environment = "prod"
    team        = "data-platform"
  }
}