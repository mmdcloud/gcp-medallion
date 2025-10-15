#---------------------------------------------------------------
# VPC Configuration
#---------------------------------------------------------------
module "vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "medallion-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "dataproc-subnet"
      region                   = "${var.location}"
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = "10.1.0.0/24"
    },
    {
      name                     = "composer-subnet"
      region                   = "${var.location}"
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = "10.2.0.0/24"
    }
  ]
  firewall_data = []
}

# --------------------------------------------------------------
# Bronze Bucket
# --------------------------------------------------------------
module "bronze_bucket" {
  source                      = "./modules/gcs"
  location                    = var.location
  name                        = "bronze-bucket"
  cors                        = []
  contents                    = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# --------------------------------------------------------------
# Silver Bucket
# --------------------------------------------------------------
module "silver_bucket" {
  source                      = "./modules/gcs"
  location                    = var.location
  name                        = "silver-bucket"
  cors                        = []
  contents                    = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# --------------------------------------------------------------
# Gold Bucket
# --------------------------------------------------------------
module "gold_bucket" {
  source                      = "./modules/gcs"
  location                    = var.location
  name                        = "gold-bucket"
  cors                        = []
  contents                    = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# --------------------------------------------------------------
# Data Governance (Dataplex)
# --------------------------------------------------------------
# Dataplex needs service account permissions to scan assets and run tasks.
# Typically you will create a dedicated service account and grant roles/dataplex.* and storage/bigquery access.

resource "google_service_account" "dataplex_sa" {
  account_id   = "dataplex-sa"
  display_name = "Dataplex service account for medallion pipelines"
}

# Grant Dataplex Admin on the lake project (example; tighten in production)
resource "google_project_iam_member" "dataplex_admin" {
  project = var.project_id
  role    = "roles/dataplex.admin"
  member  = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

# Storage access to bronze & silver buckets for Dataplex
resource "google_storage_bucket_iam_member" "bronze_reader" {
  bucket = module.bronze_bucket.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dataplex_sa.email}"
}
resource "google_storage_bucket_iam_member" "silver_writer" {
  bucket = module.silver_bucket.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

# BigQuery access for Gold
resource "google_bigquery_dataset_iam_member" "gold_bq_writer" {
  dataset_id = module.bigquery.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

# --------------------------------------------------------------
# Dataplex Lake
# --------------------------------------------------------------
resource "google_dataplex_lake" "lake" {
  project      = var.project_id
  location     = var.location
  name         = "${var.project_id}-lake"
  display_name = "Medallion Lake (${var.project_id})"
  description  = "Dataplex lake that contains bronze/silver/gold zones for medallion architecture"
  labels = {
    env   = var.project_id
    owner = "data-platform"
  }
}

# --------------------------------------------------------------
# Dataplex Zone
# --------------------------------------------------------------
resource "google_dataplex_zone" "bronze" {
  project  = var.project_id
  location = var.location
  lake     = google_dataplex_lake.lake.name
  name     = "${var.project_id}-lake-bronze"
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  display_name = "Bronze (raw)"
  type         = "RAW"
  description  = "Raw immutable landing area (GCS)"
  labels = {
    tier = "bronze"
  }
  resource_spec {
    location_type = "STORAGE"
  }
}

resource "google_dataplex_zone" "silver" {
  project  = var.project_id
  location = var.location
  lake     = google_dataplex_lake.lake.name
  name     = "${var.project_id}-lake-silver"
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  display_name = "Silver (cleaned)"
  type         = "CURATED"
  description  = "Canonical cleaned/enriched datasets"
  labels = {
    tier = "silver"
  }
  resource_spec {
    location_type = "STORAGE"
  }
}

resource "google_dataplex_zone" "gold" {
  project  = var.project_id
  location = var.location
  lake     = google_dataplex_lake.lake.name
  name     = "${var.project_id}-lake-gold"
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  display_name = "Gold (analytics-ready)"
  type         = "CURATED"
  description  = "Final analytics tables (BigQuery)"
  labels = {
    tier = "gold"
  }
  resource_spec {
    location_type = "BIGQUERY"
  }
}

# --------------------------------------------------------------
# Dataplex Assets
# --------------------------------------------------------------
resource "google_dataplex_asset" "bronze_gcs" {
  project       = var.project_id
  location      = var.location
  lake          = google_dataplex_lake.lake.name
  dataplex_zone = google_dataplex_zone.bronze.name
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  name         = "${var.project_id}-lake-bronze-gcs"
  display_name = "Bronze GCS objects"
  description  = "Raw landing data in GCS"
  resource_spec {
    name = "projects/${var.project_id}/locations/${var.location}/buckets/${module.bronze_bucket.bucket_name}"
    type = "STORAGE_BUCKET"
  }
  labels = {
    zone = "bronze"
  }
}

# Silver asset: GCS bucket (parquet/avro intermediate)
resource "google_dataplex_asset" "silver_gcs" {
  project       = var.project_id
  location      = var.location
  lake          = google_dataplex_lake.lake.name
  dataplex_zone = google_dataplex_zone.silver.name
  name          = "${var.project_id}-lake-silver-gcs"
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  display_name = "Silver GCS objects"
  description  = "Processed / canonical data in GCS"
  resource_spec {
    name = "projects/${var.project_id}/locations/${var.location}/buckets/${module.silver_bucket.bucket_name}"
    type = "STORAGE_BUCKET"
  }
  labels = {
    zone = "silver"
  }
}

# Gold asset: BigQuery dataset
resource "google_dataplex_asset" "gold_bq" {
  project       = var.project_id
  location      = var.location
  lake          = google_dataplex_lake.lake.name
  dataplex_zone = google_dataplex_zone.gold.name
  name          = "${var.project_id}-lake-gold-bq"
  discovery_spec {
    enabled          = true
    include_patterns = ["**"]
    exclude_patterns = []
    csv_options {
      header_rows = 1
      delimiter   = ","
    }
  }
  display_name = "Gold BigQuery dataset"
  description  = "Analytics-ready tables in BigQuery"
  resource_spec {
    name = "projects/${var.project_id}/datasets/${module.bigquery.dataset_id}"
    type = "BIGQUERY_DATASET"
  }
  labels = {
    zone = "gold"
  }
}

# --------------------------------------------------------------
# Dataproc configuration
# --------------------------------------------------------------
resource "google_service_account" "dataproc_sa" {
  account_id   = "dataproc-sa"
  display_name = "Dataproc Service Account"
}

module "dataproc_cluster" {
  source = "./modules/dataproc"
  autoscaling_policy = {
    policy_id = "dataproc-autoscaling-policy"
    worker_config = {
      min_instances = 2
      max_instances = 10
    }
    yarn_config = {
      graceful_decommission_timeout = "PT10M"
      scale_up_factor               = 0.8
      scale_down_factor             = 0.2
    }
    cooldown_period = "PT5M"
  }
  cluster_name   = "dataproc-cluster"
  region         = var.location
  staging_bucket = module.bronze_bucket.bucket_name
  gce_cluster_config = {
    network          = module.vpc.name
    subnetwork       = module.vpc.subnets[0].name
    service_account  = "${google_service_account.dataproc_sa.email}"
    internal_ip_only = false
    tags             = []
  }
  master_config = {
    num_instances     = 1
    machine_type      = "n1-standard-2"
    boot_disk_type    = "pd-standard"
    boot_disk_size_gb = 50
  }
  worker_config = {
    num_instances     = 2
    machine_type      = "n1-standard-2"
    boot_disk_size_gb = 50
    boot_disk_type    = "pd-standard"
  }
  software_config = {
    image_version       = "2.0-debian10"
    optional_components = ["ANACONDA", "JUPYTER"]
  }
}

# --------------------------------------------------------------
# Composer configuration
# --------------------------------------------------------------
module "airflow_dags_bucket" {
  source                      = "./modules/gcs"
  location                    = var.location
  name                        = "airflow-dags-bucket"
  cors                        = []
  contents                    = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

module "composer" {
  source        = "./modules/composer"
  composer_name = "composer-env"
  region        = var.location
  software_config = {
    image_version  = "composer-3-airflow-2"
    python_version = "3"
    pypi_packages = {
      "google-cloud-dataplex" = "1.0.0"
      "google-cloud-storage"  = "1.42.3"
      "pandas"                = "1.3.3"
    }
    env_variables = {
      "ENV"       = "prod"
      DAGS_FOLDER = "gs://${module.airflow_dags_bucket.bucket_name}/dags"
    }
  }
  node_config = {
    machine_type    = "n2-standard-8"
    network         = module.vpc.name
    subnetwork      = module.vpc.subnets[1].name
    service_account = google_service_account.dataproc_sa.email
    disk_size_gb    = 100
  }
}

# --------------------------------------------------------------
# BigQuery Dataset and Tables
# --------------------------------------------------------------
module "bigquery" {
  source     = "./modules/bigquery"
  dataset_id = "pubsubbqdataset"
  tables = [{
    table_id            = "pubsubbq-table"
    deletion_protection = false
    schema              = <<EOF
[
  {
    "name": "name",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "The data"
  },
  {
    "name": "city",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "The data"
  }
]
EOF
  }]
}