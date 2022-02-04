#################################
# Priority Class                #
#################################
# https://kubernetes.io/docs/concepts/scheduling-eviction/_print/#priorityclass
# Default:
#  NAME                      VALUE
#  system-cluster-critical   2000000000
#  system-node-critical      2000001000

resource "kubernetes_priority_class_v1" "service_monitoring_high_priority" {
  metadata {
    name = "service-monitoring-high-priority"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  value = 810000000
}

resource "kubernetes_priority_class_v1" "service_monitoring_medium_priority" {
  metadata {
    name = "service-monitoring-medium-priority"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  value = 800000000
}
