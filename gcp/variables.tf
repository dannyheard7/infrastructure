variable "project_id" {
  type        = string
  description = "The Google Cloud Project Id"
}

variable "region" {
  type    = string
  default = "us-central1"
}


variable "k8s_zone" {
  type    = string
  default = "us-central1-a"
}

variable "admin_member" {
  type        = string
  description = "Admin member alias (https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam#member/members)"
}

variable "frontend_bucket_name" {
  type    = string
  default = "www.elevait.co.uk"
}

variable "helm_version" {
  type        = string
  description = "Helm Version"
  default     = "3.4.2"
}

variable "helm_sa_name" {
  type        = string
  description = "Helm Service Account Name"
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "cycling-buddies"
}


variable "db_user_name" {
  type        = string
  description = "Database user name"
  default     = "cycling-buddies"
}


variable "db_user_password" {
  type        = string
  description = "Database user password"
}

variable "k8s_neg_name" {
  type        = string
  description = "Name of the network endpoint group in the defined region that is linked to the kubernetes service"
}