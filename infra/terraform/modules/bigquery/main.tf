
resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.dataset_id
}

resource "google_bigquery_table" "table" {
  count      = length(var.tables)
  table_id   = var.tables[count.index].table_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id

  schema = var.tables[count.index].schema
  
  deletion_protection = var.tables[count.index].deletion_protection
}