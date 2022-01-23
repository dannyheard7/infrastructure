# Container registries
resource "google_container_registry" "image_registry" {
  project  = var.project_id
  location = "EU"
}

resource "google_storage_bucket_iam_member" "image_registry_admin_member" {
  bucket = google_container_registry.image_registry.id
  role   = "roles/storage.admin"
  member = var.admin_member
}

resource "google_storage_bucket_iam_member" "image_registry_terraform_sa_iam" {
  bucket = google_container_registry.image_registry.id
  role   = "roles/storage.admin"
  member = local.terraform_sa_member
}


# Image Deployment iam user
resource "google_service_account" "gcr_image_deployment_sa" {
  account_id   = "gcr-image-deployment-sa"
  display_name = "gcr_image_deployment Account"
}

resource "google_storage_bucket_iam_member" "image_registry_gcr_image_deployment_sa-iam" {
  bucket = google_container_registry.image_registry.id
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.gcr_image_deployment_sa.email}"
}

# Database
resource "google_project_service" "sqladmin_service" {
  project = var.project_id
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "networking_service" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.default.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

resource "google_sql_database_instance" "postgres" {
  name             = "cycling-buddies-db1"
  database_version = "POSTGRES_13"
  region           = var.region

  settings {
    tier            = "db-f1-micro"
    disk_autoresize = false

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.default.id
    }

    backup_configuration {
      enabled = false
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.sqladmin_service,
    google_project_service.networking_service
  ]
}

resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}


resource "google_sql_user" "users" {
  name     = var.db_user_name
  instance = google_sql_database_instance.postgres.name
  password = var.db_user_password
}
