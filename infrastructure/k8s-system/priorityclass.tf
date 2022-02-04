#################################
# Priority Class                #
#################################
# https://kubernetes.io/docs/concepts/scheduling-eviction/_print/#priorityclass
# Default:
#  NAME                      VALUE
#  system-cluster-critical   2000000000
#  system-node-critical      2000001000

resource "kubernetes_priority_class_v1" "service_system_high_priority" {
  metadata {
    name = "service-system-high-priority"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  value = 1000000000
}

resource "kubernetes_priority_class_v1" "service_system_medium_priority" {
  metadata {
    name = "service-system-medium-priority"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  value = 900000000
}
