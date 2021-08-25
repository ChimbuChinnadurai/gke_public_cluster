resource "random_string" "np_name" {
  count   = var.nodepool_count
  length  = 6
  special = false
  upper   = false

  keepers = {
    index              = count.index
    region             = var.region
    cluster            = google_container_cluster.cluster.name
    machine_type       = var.machine_type
    oauth_scopes       = join(",", var.node_pool_oauth_scopes)
    preemptible        = var.preemptible
    initial_node_count = var.initial_node_count
    max_pods_per_node  = var.max_pods_per_node
  }

}

resource "google_container_node_pool" "np" {
  provider = google-beta
  count    = var.nodepool_count
  name     = "tenants-${random_string.np_name.*.result[count.index]}"
  location = random_string.np_name.*.keepers.region[count.index]
  cluster  = random_string.np_name.*.keepers.cluster[count.index]

  initial_node_count = var.initial_node_count
  max_pods_per_node  = var.max_pods_per_node
  version            = var.nodepool_version

  node_config {
    machine_type    = random_string.np_name.*.keepers.machine_type[count.index]
    service_account = google_service_account.cluster.email
    preemptible     = var.preemptible
    oauth_scopes    = var.node_pool_oauth_scopes
    disk_size_gb    = var.disk_size_gb
    disk_type       = var.disk_type

    labels = {
      preemptible = var.preemptible
    }

    workload_metadata_config {
      node_metadata = var.workload_metadata_from_node
    }

    shielded_instance_config {
       enable_secure_boot          = true
       enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  autoscaling {
    min_node_count = var.min_nodes_per_zone_per_pool
    max_node_count = var.max_nodes_per_zone_per_pool
  }

  management {
    auto_repair  = true
    auto_upgrade = false
  }


  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/../../scripts/drain_nodepool.sh 'np' '${count.index}' '${google_container_cluster.cluster.name}' '${var.region}' '${var.cluster_project}'"
  }
}
