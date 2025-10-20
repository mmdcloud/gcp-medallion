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