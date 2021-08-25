variable "name" {}
variable "node_subnet_range" {}
variable "pod_subnet_range" {}
variable "service_subnet_range" {}
variable "region" {}
variable "nodepool_count" {}

variable "master_version" {
  description = "The version of GKE to install on the master nodes"
}

variable "nodepool_version" {
  description = "The version of GKE to install on the nodepool nodes"
}

variable "workload_metadata_from_node" {}
variable "preemptible" {}
variable "min_nodes_per_zone_per_pool" {}
variable "max_nodes_per_zone_per_pool" {}
variable "initial_node_count" {}
variable "max_pods_per_node" {}

variable "machine_type" {}

variable "disk_type" {
  default = "pd-standard"
}

variable "disk_size_gb" {
  default = "50"
}

variable "node_pool_oauth_scopes" {
  description = "The oauth scope(s) to apply to the node pools"
  type        = list(string)
  default     = ["cloud-platform"]
}

variable "gcr_bucket_name" {
  description = "The bucket name for the Google Container Registry"
}

variable "stop_stackdriver_logging" {
  type    = string
  default = "false"
}

variable "cluster_project" {}

variable "enable_node_local_dns_cache" {
  type    = bool
  default = false
}

variable "service_name" {
  default = "kube-system"
}