#################################
# Monitoring Namespace          #
#################################

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "kube-monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}