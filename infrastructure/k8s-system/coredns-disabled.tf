#################################
# CoreDNS                       #
#################################
# https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html

/*
locals {
  coredns_name = "coredns"
}

resource "helm_release" "coredns" {
  name       = local.coredns_name
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  version    = "1.16.5"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.coredns_name
  }

  set {
    name  = "nameOverride"
    value = local.coredns_name
  }

  set {
    name  = "image.tag"
    value = "1.8.7"
  }

  set {
    name  = "replicaCount"
    value = 2
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.service_system_high_priority.metadata.0.name
  }

  set {
    name  = "service.clusterIP"
    value = var.eks_cluster_dns_ip
  }

  set {
    name  = "serviceAccount.create"
    value = true
  }

  set {
    name  = "prometheus.service.enabled"
    value = true
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
      maxUnavailable = 1
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
                  values   = [local.coredns_name]
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
                  values   = [local.coredns_name]
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
*/