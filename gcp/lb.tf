# Reserve an external IP
resource "google_compute_global_address" "website" {
  provider = google
  name     = "website-lb-ip"
}

# Get the managed DNS zone
resource "google_dns_managed_zone" "gcp_cycling_buddies" {
  provider = google
  name     = "gcp-cycling-buddies"
  dns_name = "elevait.co.uk."
}

# Add the IP to the DNS
resource "google_dns_record_set" "website" {
  provider     = google
  name         = google_dns_managed_zone.gcp_cycling_buddies.dns_name
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.gcp_cycling_buddies.name
  rrdatas      = [google_compute_global_address.website.address]
}

resource "google_dns_record_set" "dns_verification" {
  provider     = google
  name         = google_dns_managed_zone.gcp_cycling_buddies.dns_name
  type         = "TXT"
  ttl          = 300
  managed_zone = google_dns_managed_zone.gcp_cycling_buddies.name
  rrdatas      = ["google-site-verification=nYqTJI202C-oXFFHnzutfPXzrueAFKw7okjc7s0p4q4"]
}

# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "website" {
  provider = google
  name     = "website-cert"
  managed {
    domains = [google_dns_record_set.website.name]
  }
}

resource "google_compute_url_map" "website" {
  provider        = google
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website.self_link

  host_rule {
    hosts        = ["elevait.co.uk"]
    path_matcher = "elevait-main"
  }

  path_matcher {
    name            = "elevait-main"
    default_service = google_compute_backend_bucket.website.self_link

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.elevait_service_backend.self_link
    }
  }
}

# HTTPS Frontend forwarding
resource "google_compute_target_https_proxy" "https_proxy" {
  provider         = google
  name             = "website-target-proxy"
  url_map          = google_compute_url_map.website.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.website.self_link]
}


resource "google_compute_global_forwarding_rule" "https_forwading_rule" {
  name                  = "website-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.website.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.self_link
}

# HTTP Frontend forwarding
resource "google_compute_target_http_proxy" "http_proxy" {
  provider         = google
  name             = "website-http-target-proxy"
  url_map          = google_compute_url_map.website.self_link
}

resource "google_compute_global_forwarding_rule" "http_forwading_rule" {
  name                  = "website-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.website.address
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.self_link
}


# Add Email MX entries to the DNS
resource "google_dns_record_set" "email" {
  provider     = google
  name         = google_dns_managed_zone.gcp_cycling_buddies.dns_name
  type         = "MX"
  ttl          = 5
  managed_zone = google_dns_managed_zone.gcp_cycling_buddies.name
  rrdatas = [
    "10 mx.zoho.eu.",
    "20 mx2.zoho.eu.",
    "50 mx3.zoho.eu."
  ]
}

// Allow health check through firewall
resource "google_compute_firewall" "allow-health-check" {
  name          = "allow-health-check"
  network       = data.google_compute_network.default.name
  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_health_check" "http-api-health-check" {
  provider = google-beta
  name     = "http-health-check"

  timeout_sec        = 2
  check_interval_sec = 10

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/health"
  }

  log_config {
    enable = false
  }
}


data "google_compute_network_endpoint_group" "k8s_neg" {
  count = var.k8s_neg_name != "" ? 1 : 0
  name  = var.k8s_neg_name
  zone  = var.k8s_zone
}

resource "google_compute_backend_service" "elevait_service_backend" {
  provider = google
  project  = var.project_id
  name     = "elevait-service-backend"

  protocol   = "HTTP"
  enable_cdn = false

  backend {
    balancing_mode = "RATE"
    max_rate       = 800
    group          = data.google_compute_network_endpoint_group.k8s_neg[0].self_link
  }

  health_checks = [google_compute_health_check.http-api-health-check.id]
}