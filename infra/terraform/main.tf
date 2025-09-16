# --------------------------------------------------------------
# Bronze Bucket
# --------------------------------------------------------------
module "bronze_bucket" {
  source                      = "../modules/gcs"
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
module "bronze_bucket" {
  source                      = "../modules/gcs"
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
  source                      = "../modules/gcs"
  location                    = var.location
  name                        = "gold-bucket"
  cors                        = []
  contents                    = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# Dataplex needs service account permissions to scan assets and run tasks.
# Typically you will create a dedicated service account and grant roles/dataplex.* and storage/bigquery access.

resource "google_service_account" "dataplex_sa" {
  account_id   = "${var.project_id}-dataplex-sa"
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
  bucket = google_storage_bucket.bronze.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dataplex_sa.email}"
}
resource "google_storage_bucket_iam_member" "silver_writer" {
  bucket = google_storage_bucket.silver.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dataplex_sa.email}"
}

# BigQuery access for Gold
resource "google_bigquery_dataset_iam_member" "gold_bq_writer" {
  dataset_id = google_bigquery_dataset.gold.dataset_id
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
  type         = "RAW" # RAW zone for raw ingestion
  description  = "Raw immutable landing area (GCS)"
  labels = {
    tier = "bronze"
  }

  resource_spec {
    location_type = "STORAGE" # zone manages storage assets
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
    location_type = "BIGQUERY" # indicates this zone maps to BigQuery assets
  }
}


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
    # For storage bucket asset, set name in the form "projects/_/buckets/{bucket}"
    name = "projects/${var.project_id}/locations/${var.location}/buckets/${google_storage_bucket.bronze.name}"
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
    name = "projects/${var.project_id}/locations/${var.location}/buckets/${google_storage_bucket.silver.name}"
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
    # For BigQuery set name like: "projects/{project}/datasets/{dataset}"
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.gold.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  labels = {
    zone = "gold"
  }
}
