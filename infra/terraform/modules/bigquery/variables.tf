variable "dataset_id" {}
variable "tables" {
  type = list(object({
    table_id            = string
    schema              = string
    deletion_protection = bool
  }))
}
