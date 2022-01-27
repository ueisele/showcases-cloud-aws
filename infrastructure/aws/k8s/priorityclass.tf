#################################
# Priority Class                #
#################################
# https://kubernetes.io/docs/concepts/scheduling-eviction/_print/#priorityclass
# Default:
#  NAME                      VALUE
#  system-cluster-critical   2000000000
#  system-node-critical      2000001000

resource "kubernetes_priority_class_v1" "high-priority-system-service" {
  metadata {
    name = "high-priority-system-service"
    annotations = {
        terraform = "true"
    }
  }

  value = 1000000000
}

resource "kubernetes_priority_class_v1" "medium-priority-system-service" {
  metadata {
    name = "medium-priority-system-service"
    annotations = {
        terraform = "true"
    }
  }

  value = 900000000
}