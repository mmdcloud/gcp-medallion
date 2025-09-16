# --------------------------------------------------------------
# Bronze Bucket
# --------------------------------------------------------------
module "bronze_bucket" {
  source   = "../modules/gcs"
  location = var.location
  name     = "bronze-bucket"
  cors     = []
  contents = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# --------------------------------------------------------------
# Silver Bucket
# --------------------------------------------------------------
module "bronze_bucket" {
  source   = "../modules/gcs"
  location = var.location
  name     = "silver-bucket"
  cors     = []
  contents = []
  force_destroy               = true
  uniform_bucket_level_access = true
}

# --------------------------------------------------------------
# Gold Bucket
# --------------------------------------------------------------
module "bronze_bucket" {
  source   = "../modules/gcs"
  location = var.location
  name     = "gold-bucket"
  cors     = []
  contents = []
  force_destroy               = true
  uniform_bucket_level_access = true
}