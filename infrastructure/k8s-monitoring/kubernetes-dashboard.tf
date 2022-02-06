#################################
# Kubernetes Dashboard          #
#################################
# https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
# https://github.com/kubernetes/dashboard

locals {
  kubernetes_dashboard_name                 = "kubernetes-dashboard"
  kubernetes_dashboard_metrics_scraper_name = "dashboard-metrics-scraper" // Do not changes! Kubernetes dashboard expects this name!
}

resource "kubernetes_service_account_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_secret_v1" "kubernetes_dashboard_csrf" {
  metadata {
    name      = "${local.kubernetes_dashboard_name}-csrf"
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  data = {
    csrf = ""
  }
}

resource "kubernetes_secret_v1" "kubernetes_dashboard_key_holder" {
  metadata {
    name      = "${local.kubernetes_dashboard_name}-key-holder"
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_config_map_v1" "kubernetes_dashboard_settings" {
  metadata {
    name      = "${local.kubernetes_dashboard_name}-settings"
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_role_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["${local.kubernetes_dashboard_name}-key-holder", "${local.kubernetes_dashboard_name}-csrf"]
    verbs          = ["get", "update", "delete"]
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["${local.kubernetes_dashboard_name}-settings"]
    verbs          = ["get", "update"]
  }
  rule {
    api_groups     = [""]
    resources      = ["services"]
    resource_names = [local.kubernetes_dashboard_metrics_scraper_name]
    verbs          = ["proxy"]
  }
  rule {
    api_groups     = [""]
    resources      = ["services/proxy"]
    resource_names = [local.kubernetes_dashboard_metrics_scraper_name, "http:${local.kubernetes_dashboard_metrics_scraper_name}"]
    verbs          = ["get"]
  }
}

resource "kubernetes_cluster_role_v1" "kubernetes_dashboard" {
  metadata {
    name = local.kubernetes_dashboard_name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = local.kubernetes_dashboard_name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubernetes_dashboard" {
  metadata {
    name = local.kubernetes_dashboard_name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.kubernetes_dashboard_name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
  }
}

resource "kubernetes_ingress_v1" "kubernetes_dashboard" {
  count = var.kubernetes_dashboard_expose ? 1 : 0

  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "${local.kubernetes_dashboard_name}.${local.env_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.kubernetes_dashboard.metadata.0.name
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

output "kubernetes_dashboard_url" {
  value = "${local.kubernetes_dashboard_name}.${local.env_domain}"
}

resource "kubernetes_service_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"     = local.kubernetes_dashboard_name
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 9090
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
        "app.kubernetes.io/name"     = local.kubernetes_dashboard_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
          "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kubernetes_dashboard.metadata.0.name
        priority_class_name  = kubernetes_priority_class_v1.service_monitoring_medium_priority.metadata.0.name
        container {
          image = "kubernetesui/dashboard:v2.5.0"
          name  = local.kubernetes_dashboard_name

          args = [
            "--enable-insecure-login",
            "--namespace=${kubernetes_namespace_v1.monitoring.metadata.0.name}"
          ]

          port {
            container_port = 9090
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/"
              port   = 9090
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 1001
            run_as_group              = 2001
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-volume"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {}
        }

        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values   = ["arm64"]
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/os"
                  operator = "In"
                  values   = ["linux"]
                }
                match_expressions {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values   = ["amd64", "arm64"]
                }
              }
            }
          }
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kubernetes_dashboard_name]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kubernetes_dashboard_name]
                }
              }
              topology_key = "failure-domain.beta.kubernetes.io/zone"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "kubernetes_dashboard" {
  metadata {
    name      = local.kubernetes_dashboard_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
        "app.kubernetes.io/name"     = local.kubernetes_dashboard_name
      }
    }
  }
}

resource "kubernetes_service_v1" "kubernetes_dashboard_metrics_scraper" {
  metadata {
    name      = local.kubernetes_dashboard_metrics_scraper_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_metrics_scraper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"     = local.kubernetes_dashboard_metrics_scraper_name
    }
    session_affinity = "ClientIP"
    port {
      port        = 8000
      target_port = 8000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set_v1" "kubernetes_dashboard_metrics_scraper" {
  metadata {
    name      = local.kubernetes_dashboard_metrics_scraper_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_metrics_scraper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    replicas              = 1
    pod_management_policy = "Parallel"

    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }

    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
        "app.kubernetes.io/name"     = local.kubernetes_dashboard_metrics_scraper_name
      }
    }

    service_name = local.kubernetes_dashboard_metrics_scraper_name

    template {
      metadata {
        labels = {
          "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
          "app.kubernetes.io/name"       = local.kubernetes_dashboard_metrics_scraper_name
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kubernetes_dashboard.metadata.0.name
        priority_class_name  = kubernetes_priority_class_v1.service_monitoring_medium_priority.metadata.0.name
        container {
          image = "kubernetesui/metrics-scraper:v1.0.7"
          name  = local.kubernetes_dashboard_metrics_scraper_name

          args = [
            "--metric-resolution=30s",
            "--metric-duration=2h",
            "--db-file=/tmp/metrics.db"
          ]

          port {
            container_port = 8000
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/"
              port   = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 1001
            run_as_group              = 2001
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "data"
          }
        }

        toleration {
          key      = "system"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }

        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values   = ["arm64"]
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/os"
                  operator = "In"
                  values   = ["linux"]
                }
                match_expressions {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values   = ["amd64", "arm64"]
                }
              }
            }
          }
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kubernetes_dashboard_metrics_scraper_name]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.kubernetes_dashboard_metrics_scraper_name]
                }
              }
              topology_key = "failure-domain.beta.kubernetes.io/zone"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
        labels = {
          "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
          "app.kubernetes.io/name"       = local.kubernetes_dashboard_metrics_scraper_name
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }
      spec {
        access_modes       = ["ReadWriteMany"]
        storage_class_name = "efs"
        resources {
          requests = {
            storage = "25Mi"
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "kubernetes_dashboard_metrics_scraper" {
  metadata {
    name      = local.kubernetes_dashboard_metrics_scraper_name
    namespace = kubernetes_namespace_v1.monitoring.metadata.0.name
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_metrics_scraper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.kubernetes_dashboard_name
        "app.kubernetes.io/name"     = local.kubernetes_dashboard_metrics_scraper_name
      }
    }
  }
}

#################################
# Read Only Service Account     #
#################################

resource "kubernetes_cluster_role_v1" "kubernetes_dashboard_readonly_cluster" {
  metadata {
    name = "${local.kubernetes_dashboard_name}-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "endpoints",
      "persistentvolumeclaims",
      "pods",
      "replicationcontrollers",
      "replicationcontrollers/scale",
      "serviceaccounts",
      "services",
      "nodes",
      "persistentvolumeclaims",
      "persistentvolumes"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources = [
      "bindings",
      "events",
      "limitranges",
      "namespaces/status",
      "pods/log",
      "pods/status",
      "replicationcontrollers/status",
      "resourcequotas",
      "resourcequotas/status"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources = [
      "namespaces"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources = [
      "daemonsets",
      "deployments",
      "deployments/scale",
      "replicasets",
      "replicasets/scale",
      "statefulsets"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["autoscaling"]
    resources = [
      "horizontalpodautoscalers"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["batch"]
    resources = [
      "cronjobs",
      "jobs"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources = [
      "daemonsets",
      "deployments",
      "deployments/scale",
      "ingresses",
      "networkpolicies",
      "replicasets",
      "replicasets/scale",
      "replicationcontrollers/scale"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["policy"]
    resources = [
      "poddisruptionbudgets"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources = [
      "networkpolicies",
      "ingresses"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources = [
      "storageclasses",
      "volumeattachments"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "clusterrolebindings",
      "clusterroles",
      "roles",
      "rolebindings"
    ]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_service_account_v1" "kubernetes_dashboard_readonly_cluster" {
  metadata {
    name = "${local.kubernetes_dashboard_name}-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubernetes_dashboard_readonly_cluster" {
  metadata {
    name = "${local.kubernetes_dashboard_name}-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = local.kubernetes_dashboard_name
      "app.kubernetes.io/name"       = local.kubernetes_dashboard_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kubernetes_dashboard_readonly_cluster.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.metadata.0.name
    namespace = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.metadata.0.namespace
  }
}

data "kubernetes_secret_v1" "kubernetes_dashboard_readonly_cluster_token" {
  metadata {
    name      = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.default_secret_name
    namespace = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.metadata.0.namespace
  }
}

output "kubernetes_dashboard_readonly_cluster_token" {
  value     = data.kubernetes_secret_v1.kubernetes_dashboard_readonly_cluster_token.data.token
  sensitive = true
}
