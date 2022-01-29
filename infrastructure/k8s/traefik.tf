#################################
# Traefik                       #
#################################
# https://doc.traefik.io/traefik/
# https://github.com/traefik/traefik-helm-chart

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "10.9.1"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "traefik"
  }

  set {
    name  = "nameOverride"
    value = "traefik"
  }

  set {
    name  = "image.tag"
    value = "2.6.0"
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.high-priority-system-service.metadata.0.name
  }

  values = [yamlencode({
    deployment = {
      replicas = 3
    }

    podDisruptionBudget = {
      enabled        = true
      maxUnavailable = 1
    }

    ingressClass = {
      enabled        = true
      isDefaultClass = true
    }

    ingressRoute = {
      dashboard = {
        enabled = false
      }
    }

    providers = {
      kubernetesCRD = {
        enabled                   = true
        allowCrossNamespace       = true
        allowExternalNameServices = true
      }
      kubernetesIngress = {
        enabled                   = true
        allowExternalNameServices = true
        publishedService = {
          enabled = true
          # Published Kubernetes Service to copy status from. Format: namespace/servicename
        }
      }
    }

    ports = {
      web = {
        port       = 8000
        expose     = true
        exposePort = 80
        protocol   = "TCP"
      }
      websecure = {
        port       = 8443
        expose     = true
        exposePort = 443
        protocol   = "TCP"
        tls = {
          enabled = false
          # terminated by NLB
        }
      }
      traefik = {
        port       = 9000
        expose     = false
        exposePort = 9000
        protocol   = "TCP"
      }
      metrics = {
        port       = 9100
        expose     = false
        exposePort = 9100
        protocol   = "TCP"
      }
    }

    service = {
      enabled = true
      type    = "LoadBalancer"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
        "service.beta.kubernetes.io/aws-load-balancer-ip-address-type"                   = "dualstack"
        "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                         = "443"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                          = data.aws_acm_certificate.public.arn
        "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
        "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "false"
      }
      annotationsTCP = {
        "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
      }
      annotationsUDP = {
        "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "udp"
      }
    }

    resources = {
      limits = {
        cpu    = "250m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "250m"
        memory = "200Mi"
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
                values   = ["traefik"]
              }]
            }
            topologyKey = "kubernetes.io/hostname"
          },
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["traefik"]
              }]
            }
            topologyKey = "failure-domain.beta.kubernetes.io/zone"
          }
        ]
      }
    }
  })]
}

#################################
# Middleware                    #
#################################

resource "random_password" "traefik-basic-auth-default" {
  length           = 16
  special          = true
  override_special = "%=?@+#"
}

output "traefik-basic-auth-default-credentials" {
  value     = "admin:${random_password.traefik-basic-auth-default.result}"
  sensitive = true
}

resource "kubernetes_secret_v1" "traefik-basic-auth-default" {
  metadata {
    name      = "traefik-basic-auth-default"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "traefik"
      "app.kubernetes.io/name"       = "traefik"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  # Note: in a kubernetes secret the string (e.g. generated by htpasswd) must be base64-encoded first.
  # To create an encoded user:password pair, the following command can be used:
  # htpasswd -nb user password | openssl base64
  data = {
    users = "admin:${bcrypt(random_password.traefik-basic-auth-default.result)}"
  }
}

# https://doc.traefik.io/traefik/middlewares/http/basicauth/
resource "kubectl_manifest" "traefik-middleware-basic-auth-default" {
  yaml_body = <<-EOF
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: basic-auth-default
      namespace: kube-system
      labels:
        app.kubernetes.io/instance: traefik
        app.kubernetes.io/name: traefik
        app.kubernetes.io/managed-by: Terraform
    spec:
      basicAuth:
        secret: ${kubernetes_secret_v1.traefik-basic-auth-default.metadata.0.name}
    EOF

  depends_on = [helm_release.traefik, kubernetes_secret_v1.traefik-basic-auth-default]
}

#################################
# Traefik Dashboard             #
#################################

resource "kubectl_manifest" "ingressroute-traefik-dashboard" {
  yaml_body = <<-EOF
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: traefik-dashboard
      namespace: kube-system      
      labels:
        app.kubernetes.io/instance: traefik
        app.kubernetes.io/name: traefik
        app.kubernetes.io/managed-by: Terraform
    spec:
      entryPoints:
      - traefik
      routes:
      - kind: Rule
        match: Host(`traefik.${local.env_domain}`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)
        services:
        - kind: TraefikService
          name: api@internal
    EOF

  depends_on = [helm_release.traefik]
}

resource "kubernetes_service_v1" "traefik-dashboard" {
  count = var.traefik_dashboard_expose ? 1 : 0

  metadata {
    name      = "traefik-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "traefik"
      "app.kubernetes.io/name"       = "traefik"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "traefik"
      "app.kubernetes.io/name"     = "traefik"
    }
    port {
      name        = "http"
      port        = 80
      target_port = "traefik"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "traefik-dashboard" {
  count = var.traefik_dashboard_expose ? 1 : 0

  metadata {
    name      = "traefik-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "traefik"
      "app.kubernetes.io/name"       = "traefik"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.middlewares" = "${kubectl_manifest.traefik-middleware-basic-auth-default.namespace}-${kubectl_manifest.traefik-middleware-basic-auth-default.name}@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "traefik.${local.env_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.traefik-dashboard[0].metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
