# Bucket 
resource "google_storage_bucket" "frontend" {
  provider                    = google
  name                        = var.frontend_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

# Bucket Deployment iam user
resource "google_service_account" "frontend_bucket_deployment_sa" {
  account_id   = "frontend-bucket-deployment-sa"
  display_name = "frontend_bucket_deployment Account"
}

resource "google_storage_bucket_iam_member" "frontend_bucket_admin_member" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.admin"
  member = var.admin_member
}

resource "google_storage_bucket_iam_member" "frontend_bucket_terraform_sa-iam" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.admin"
  member = local.terraform_sa_member
}

resource "google_storage_bucket_iam_member" "frontend_bucket_deployment_sa-iam" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.frontend_bucket_deployment_sa.email}"
}

resource "google_storage_bucket_iam_member" "frontend_bucket_terraform_allusers_view" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Networking 
resource "google_compute_backend_bucket" "website" {
  provider    = google
  name        = "website-backend"
  description = "Contains files needed by the frontend"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true
}

