#################################
# Kubernetes Metrics Server     #
#################################
# https://github.com/kubernetes-sigs/metrics-server

locals {
  kube_metrics_server_name = "kube-metrics-server"
}

resource "helm_release" "kube_metrics_server" {
  name       = local.kube_metrics_server_name
  repository = "./charts"
  chart      = "metrics-server"
  version    = "3.8.0"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.kube_metrics_server_name
  }

  set {
    name  = "nameOverride"
    value = local.kube_metrics_server_name
  }

  set {
    name  = "replicas"
    value = 2
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.service_system_high_priority.metadata.0.name
  }

  values = [yamlencode({
    resources = {
      limits = {
        cpu    = "100m"
        memory = "64Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "64Mi"
      }
    }

    podDisruptionBudget = {
      enabled        = true
      maxUnavailable = 1
    }

    updateStrategy = {
      type = "RollingUpdate"
      rollingUpdate = {
        maxUnavailable = 1
      }
    }

    affinity = {
      nodeAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            preference = {
              matchExpressions = [{
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = ["arm64"]
              }]
            }
          }
        ],
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [
              {
                key      = "kubernetes.io/os"
                operator = "In"
                values   = ["linux"]
              },
              {
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = ["amd64", "arm64"]
              }
            ]
          }]
        }
      }
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kube_metrics_server_name]
                }]
              }
              topologyKey = "kubernetes.io/hostname"
            }
            weight = 50
          },
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kube_metrics_server_name]
                }]
              }
              topologyKey = "failure-domain.beta.kubernetes.io/zone"
            }
            weight = 25
          }
        ]
      }
    }
  })]
}
