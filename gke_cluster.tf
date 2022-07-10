resource "random_string" "cluster_database_encryption" {
  length  = 6
  lower   = true
  special = false
}

resource "google_kms_key_ring" "cluster_database_encryption_keyring" {
  project  = data.google_client_config.current.project
  name     = "database-encryption-keyring-${random_string.cluster_database_encryption.result}"
  location = var.region
}

resource "google_kms_crypto_key" "cluster_database_encryption_crypto_key" {
  name     = "database-encryption-crypto-key"
  key_ring = google_kms_key_ring.cluster_database_encryption_keyring.id
  # 90 days
  rotation_period = "7776000s"
}

resource "google_kms_crypto_key_iam_binding" "cluster_service_account_can_use_key" {
  crypto_key_id = google_kms_crypto_key.cluster_database_encryption_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${data.google_project.cluster_project.number}@container-engine-robot.iam.gserviceaccount.com",

  ]
}

resource "google_container_cluster" "cluster" {
  provider = google-beta
  name     = var.name
  location = var.region

  release_channel {
    channel = "UNSPECIFIED"
  }

  network = google_compute_network.vpc.name

  subnetwork = google_compute_subnetwork.vpc_regional_subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  min_master_version = var.master_version

  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"

  initial_node_count       = 1
  remove_default_node_pool = true
  enable_shielded_nodes = true

  vertical_pod_autoscaling {
    enabled = true
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.cluster_database_encryption_crypto_key.id

  }

  workload_identity_config {
    identity_namespace = "${data.google_client_config.current.project}.svc.id.goog"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "public"
    }
  }

  network_policy {
    enabled  = false
    provider = "CALICO"
  }

  pod_security_policy_config {
    enabled = false
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00"
    }
  }

  #resource_usage_export_config {
  #  enable_network_egress_metering = true
  #
  #  bigquery_destination {
  #    dataset_id = "usage_metering_dataset"
  #  }
  #}

  addons_config {
    dns_cache_config {
      enabled = var.enable_node_local_dns_cache
    }
    istio_config {
      disabled  = true
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }

    username = ""
    password = ""
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
      resource_labels,
      network_policy
    ]
  }

  depends_on = [
    google_kms_key_ring.cluster_database_encryption_keyring,
    google_kms_crypto_key.cluster_database_encryption_crypto_key,
    google_kms_crypto_key_iam_binding.cluster_service_account_can_use_key
  ]
}

# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
resource "google_service_account" "cluster" {
  account_id   = var.name
  display_name = "Default service account for nodes of cluster ${google_container_cluster.cluster.name}"
}

resource "google_project_iam_member" "gke_node_logwriter" {
  member = "serviceAccount:${google_service_account.cluster.email}"
  role   = "roles/logging.logWriter"
}

resource "google_project_iam_member" "gke_node_metricwriter" {
  member = "serviceAccount:${google_service_account.cluster.email}"
  role   = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "gke_node_monitoringviewer" {
  member = "serviceAccount:${google_service_account.cluster.email}"
  role   = "roles/monitoring.viewer"
}

resource "google_storage_bucket_iam_member" "gke_node_gcr_viewer" {
  bucket = var.gcr_bucket_name
  member = "serviceAccount:${google_service_account.cluster.email}"
  role   = "roles/storage.objectViewer"
}
