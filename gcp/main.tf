data "google_client_config" "current" {}

data "google_client_openid_userinfo" "terraform_sa" {}

locals {
  terraform_sa_member = "serviceAccount:${data.google_client_openid_userinfo.terraform_sa.email}"
}
