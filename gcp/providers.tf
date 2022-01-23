terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.53.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "3.53.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}


terraform {
  backend "gcs" {
    bucket = "organic-area-299215-tfstate"
    prefix = "root\tfsate"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

