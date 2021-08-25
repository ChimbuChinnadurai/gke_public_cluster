data "google_client_config" "current" {}
data "google_project" "cluster_project" {}

resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "vpc_regional_subnet" {
  name          = "${var.name}-${var.region}"
  network       = google_compute_network.vpc.name
  region        = var.region
  ip_cidr_range = var.node_subnet_range

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pod_subnet_range
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.service_subnet_range
  }

  lifecycle {
    ignore_changes = [
      secondary_ip_range[0].ip_cidr_range,
      secondary_ip_range[1].ip_cidr_range,
    ]
  }
}