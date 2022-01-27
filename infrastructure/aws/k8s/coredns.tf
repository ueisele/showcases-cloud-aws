#################################
# CoreDNS                       #
#################################
# https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html

resource "helm_release" "coredns" {
  name       = "coredns"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  version    = "1.16.5"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "coredns"
  }

  set {
    name  = "nameOverride"
    value = "coredns"
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
    value = kubernetes_priority_class_v1.high-priority-system-service.metadata.0.name
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
        memory = "192Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "128Mi"
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
                values   = ["coredns"]
              }]
            }
            topologyKey = "kubernetes.io/hostname"
          },
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["coredns"]
              }]
            }
            topologyKey = "failure-domain.beta.kubernetes.io/zone"
          }
        ]
      }
    }
  })]
}

## CoreDNS EKS Addon
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
# Cannot be used, because EKS add-ons do not support tolerations
/*
resource "aws_eks_addon" "coredns" {
  cluster_name      = data.aws_eks_cluster.main.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "coredns"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}
*/
