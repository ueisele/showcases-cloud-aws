#################################
# Traefik                       #
#################################
# https://doc.traefik.io/traefik/
# https://github.com/traefik/traefik-helm-chart

locals {
  traefik_name              = "traefik"
  traefik_ingressclass_name = local.traefik_name
}

resource "helm_release" "traefik" {
  name       = local.traefik_name
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "10.14.0"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.traefik_name
  }

  set {
    name  = "nameOverride"
    value = local.traefik_name
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.service_system_high_priority.metadata.0.name
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
        requiredDuringSchedulingIgnoredDuringExecution = [
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = [local.traefik_name]
              }]
            }
            topologyKey = "kubernetes.io/hostname"
          },
          {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = [local.traefik_name]
              }]
            }
            topologyKey = "failure-domain.beta.kubernetes.io/zone"
          }
        ]
      }
    }
  })]

  depends_on = [kubernetes_ingress_class_v1.alb]
}

#################################
# Middleware                    #
#################################

resource "random_password" "traefik_basic_auth_default" {
  length           = 16
  special          = true
  override_special = "%=?@+#"
}

output "traefik_basic_auth_default_credentials" {
  value     = "admin:${random_password.traefik_basic_auth_default.result}"
  sensitive = true
}

resource "kubernetes_secret_v1" "traefik_basic_auth_default" {
  metadata {
    name      = "${local.traefik_name}-basic-auth-default"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.traefik_name
      "app.kubernetes.io/name"       = local.traefik_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  # Note: in a kubernetes secret the string (e.g. generated by htpasswd) must be base64-encoded first.
  # To create an encoded user:password pair, the following command can be used:
  # htpasswd -nb user password | openssl base64
  data = {
    users = "admin:${bcrypt(random_password.traefik_basic_auth_default.result)}"
  }
}

# https://doc.traefik.io/traefik/middlewares/http/basicauth/
resource "kubectl_manifest" "traefik_middleware_basic_auth_default" {
  yaml_body = <<-EOF
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: basic-auth-default
      namespace: kube-system
      labels:
        app.kubernetes.io/instance: ${local.traefik_name}
        app.kubernetes.io/name: ${local.traefik_name}
        app.kubernetes.io/managed-by: Terraform
    spec:
      basicAuth:
        secret: ${kubernetes_secret_v1.traefik_basic_auth_default.metadata.0.name}
    EOF

  depends_on = [helm_release.traefik, kubernetes_secret_v1.traefik_basic_auth_default]
}

#################################
# Traefik Dashboard             #
#################################

resource "kubectl_manifest" "ingressroute_traefik_dashboard" {
  yaml_body = <<-EOF
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: ${local.traefik_name}-dashboard
      namespace: kube-system      
      labels:
        app.kubernetes.io/instance: ${local.traefik_name}
        app.kubernetes.io/name: ${local.traefik_name}
        app.kubernetes.io/managed-by: Terraform
    spec:
      entryPoints:
      - traefik
      routes:
      - kind: Rule
        match: Host(`${local.traefik_name}.${local.env_domain}`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)
        services:
        - kind: TraefikService
          name: api@internal
    EOF

  depends_on = [helm_release.traefik]
}

resource "kubernetes_service_v1" "traefik_dashboard" {
  count = var.traefik_dashboard_expose ? 1 : 0

  metadata {
    name      = "${local.traefik_name}-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.traefik_name
      "app.kubernetes.io/name"       = local.traefik_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = local.traefik_name
      "app.kubernetes.io/name"     = local.traefik_name
    }
    port {
      name        = "http"
      port        = 80
      target_port = "traefik"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "traefik_dashboard" {
  count = var.traefik_dashboard_expose ? 1 : 0

  metadata {
    name      = "${local.traefik_name}-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.traefik_name
      "app.kubernetes.io/name"       = local.traefik_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.middlewares" = "${kubectl_manifest.traefik_middleware_basic_auth_default.namespace}-${kubectl_manifest.traefik_middleware_basic_auth_default.name}@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = local.traefik_ingressclass_name
    rule {
      host = "${local.traefik_name}.${local.env_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.traefik_dashboard[0].metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.traefik,
    helm_release.external_dns_controller
  ]
}

output "traefik_dashboard_url" {
  value = "${local.traefik_name}.${local.env_domain}"
}
