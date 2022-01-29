#################################
# Kubernetes Metrics Server     #
#################################
# https://github.com/kubernetes-sigs/metrics-server

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "./charts"
  chart      = "metrics-server"
  version    = "3.8.0"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "metrics-server"
  }

  set {
    name  = "nameOverride"
    value = "metrics-server"
  }

  set {
    name  = "replicas"
    value = 2
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.high-priority-system-service.metadata.0.name
  }

  values = [yamlencode({
    resources = {
      limits = {
        cpu    = "100m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "200Mi"
      }
    }

    podDisruptionBudget = {
      enabled        = true
      minAvailable = 1
    }

    updateStrategy = {
      type           = "RollingUpdate"
      rollingUpdate = {
        maxUnavailable = 1
      }
    }

    tolerations = [{
      key      = "system"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]

    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [
              {
                key      = "eks.amazonaws.com/nodegroup"
                operator = "In"
                values   = [local.eks_cluster_system_node_group_name]
              },
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
        requiredDuringSchedulingIgnoredDuringExecution = [
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["metrics-server"]
              }]
            }
            topologyKey = "kubernetes.io/hostname"
          },
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["metrics-server"]
              }]
            }
            topologyKey = "failure-domain.beta.kubernetes.io/zone"
          }
        ]
      }
    }
  })]
}
