resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = "${var.project_id}-gke-1"
  project  = var.project_id
  location = var.k8s_zone

  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"

  monitoring_service = "none"
  logging_service    = "logging.googleapis.com/kubernetes"

  ip_allocation_policy {}

  release_channel {
    channel = "REGULAR"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.16/28"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name           = "my-node-pool"
  location       = var.k8s_zone
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  node_locations = [var.k8s_zone]

  node_config {
    preemptible  = true
    machine_type = "g1-small"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

provider "kubernetes" {
  host  = "https://${google_container_cluster.primary.endpoint}"
  token = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate,
  )
}

resource "kubernetes_service_account" "helm_account" {
  provider = kubernetes
  depends_on = [
    google_container_cluster.primary,
  ]
  metadata {
    name      = var.helm_sa_name
    namespace = "kube-system"
  }
}

// TODO: make project admin permission to view this sa
// We should do this for all the sas
module "kubernetes-engine_workload-identity" {
  source      = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version     = "12.3.0"
  k8s_sa_name = var.helm_sa_name
  name        = var.helm_sa_name
  project_id  = var.project_id
}

resource "google_project_iam_member" "helm_sa_container_admin_iam" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${module.kubernetes-engine_workload-identity.gcp_service_account_email}"
}

resource "kubernetes_cluster_role_binding" "helm_role_binding" {
  metadata {
    name = kubernetes_service_account.helm_account.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.helm_account.metadata.0.name
    namespace = "kube-system"
  }
  provisioner "local-exec" {
    command = "sleep 15"
  }
}

# provider "helm" {
#   service_account = kubernetes_service_account.helm_account.metadata.0.name
#   tiller_image    = "gcr.io/kubernetes-helm/tiller:${var.helm_version}"

#   kubernetes {
#     host                   = google_container_cluster.primary.endpoint
#     token                  = data.google_client_config.current.access_token
#     client_certificate     = base64decode(google_container_cluster.default.master_auth.0.client_certificate)
#     client_key             = base64decode(google_container_cluster.default.master_auth.0.client_key)
#     cluster_ca_certificate = base64decode(google_container_cluster.default.master_auth.0.cluster_ca_certificate)
#   }
# }


// LB backend


