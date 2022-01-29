#################################
# Kubernetes Dashboard          #
#################################
# https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
# https://github.com/kubernetes/dashboard

resource "kubernetes_service_account_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_secret_v1" "kubernetes_dashboard_csrf" {
  metadata {
    name = "kubernetes-dashboard-csrf"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  data = {
    csrf = ""
  }
}

resource "kubernetes_secret_v1" "kubernetes_dashboard_key_holder" {
  metadata {
    name = "kubernetes-dashboard-key-holder"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_config_map_v1" "kubernetes_dashboard_settings" {
  metadata {
    name = "kubernetes-dashboard-settings"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_role_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-csrf"]
    verbs          = ["get", "update", "delete"]
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["kubernetes-dashboard-settings"]
    verbs          = ["get", "update"]
  }
  rule {
    api_groups     = [""]
    resources      = ["services"]
    resource_names = ["dashboard-metrics-scraper"]
    verbs          = ["proxy"]
  }
  rule {
    api_groups     = [""]
    resources      = ["services/proxy"]
    resource_names = ["dashboard-metrics-scraper", "http:dashboard-metrics-scraper"]
    verbs          = ["get"]
  }
}

resource "kubernetes_cluster_role_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
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
    name = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kubernetes-dashboard"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "kubernetes-dashboard"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
  }
}

resource "kubernetes_service_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
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
    name = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    replicas = 2

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        "app.kubernetes.io/instance"   = "kubernetes-dashboard"
        "app.kubernetes.io/name"       = "kubernetes-dashboard"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/instance"   = "kubernetes-dashboard"
          "app.kubernetes.io/name"       = "kubernetes-dashboard"
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kubernetes_dashboard.metadata.0.name
        container {
          image = "kubernetesui/dashboard:v2.4.0"
          name  = "kubernetes-dashboard"

          args = [ 
            "--enable-insecure-login",
            "--namespace=kube-system"
          ]

          port {
            container_port = 9090
            protocol = "TCP"
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path = "/"
              port = 9090
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
            run_as_user = 1001
            run_as_group = 2001
          }

          volume_mount {
            mount_path = "/tmp"
            name = "tmp-volume"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {}
        }

        toleration {
          key      = "system"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "In"
                  values   = [local.eks_cluster_system_node_group_name]
                }
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
                  values   = ["kubernetes-dashboard"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["kubernetes-dashboard"]
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
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = "kubernetes-dashboard"
        "app.kubernetes.io/name"     = "kubernetes-dashboard"
      }
    }
  }
}

resource "kubernetes_service_v1" "dashboard_metrics_scraper" {
  metadata {
    name = "dashboard-metrics-scraper"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
    }
    session_affinity = "ClientIP"
    port {
      port        = 8000
      target_port = 8000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set_v1" "dashboard_metrics_scraper" {
  metadata {
    name = "dashboard-metrics-scraper"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    replicas = 2
    pod_management_policy = "Parallel"

    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }

    selector {
      match_labels = {
        "app.kubernetes.io/instance"   = "kubernetes-dashboard"
        "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
      }
    }

    service_name = "dashboard-metrics-scraper"

    template {
      metadata {
        labels = {
          "app.kubernetes.io/instance"   = "kubernetes-dashboard"
          "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kubernetes_dashboard.metadata.0.name
        container {
          image = "kubernetesui/metrics-scraper:v1.0.7"
          name  = "dashboard-metrics-scraper"

          args = [ 
            "--metric-resolution=30s",
            "--metric-duration=30m",
            "--db-file=/tmp/metrics.db"
          ]

          port {
            container_port = 8000
            protocol = "TCP"
          }

          liveness_probe {
            http_get {
              scheme = "HTTP"
              path = "/"
              port = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          resources {
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          security_context {
            read_only_root_filesystem = true
            run_as_user = 1001
            run_as_group = 2001
          }

          volume_mount {
            mount_path = "/tmp"
            name = "data"
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
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "In"
                  values   = [local.eks_cluster_system_node_group_name]
                }
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
                  values   = ["dashboard-metrics-scraper"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["dashboard-metrics-scraper"]
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
          "app.kubernetes.io/instance"   = "kubernetes-dashboard"
          "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }
      spec {
        access_modes       = ["ReadWriteMany"]
        storage_class_name = "efs"
        resources {
          requests = {
            storage = "50Mi"
          }
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "dashboard_metrics_scraper" {
  metadata {
    name      = "dashboard-metrics-scraper"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "dashboard-metrics-scraper"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = "kubernetes-dashboard"
        "app.kubernetes.io/name"     = "dashboard-metrics-scraper"
      }
    }
  }
}

resource "kubernetes_ingress_v1" "kubernetes_dashboard" {
  count = var.kubernetes_dashboard_expose ? 1 : 0

  metadata {
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      //"traefik.ingress.kubernetes.io/router.middlewares" = "${kubectl_manifest.traefik-middleware-basic-auth-default.namespace}-${kubectl_manifest.traefik-middleware-basic-auth-default.name}@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "kubernetes-dashboard.${local.env_domain}"
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

#################################
# Read Only Service Account     #
#################################

resource "kubernetes_cluster_role_v1" "kubernetes_dashboard_readonly_cluster" {
  metadata {
    name = "kubernetes-dashboard-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = [
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
    resources  = [
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
    resources  = [
      "namespaces"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = [
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
    resources  = [
      "horizontalpodautoscalers"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["batch"]
    resources  = [
      "cronjobs",
      "jobs"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = [
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
    resources  = [
      "poddisruptionbudgets"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = [
      "networkpolicies",
      "ingresses"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = [
      "storageclasses",
      "volumeattachments"
    ]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = [
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
    name = "kubernetes-dashboard-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubernetes_dashboard_readonly_cluster" {
  metadata {
    name = "kubernetes-dashboard-readonly-cluster"
    labels = {
      "app.kubernetes.io/instance"   = "kubernetes-dashboard"
      "app.kubernetes.io/name"       = "kubernetes-dashboard"
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
    name = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.default_secret_name
    namespace = kubernetes_service_account_v1.kubernetes_dashboard_readonly_cluster.metadata.0.namespace
  }
}

output kubernetes_dashboard_readonly_cluster_token {
    value = data.kubernetes_secret_v1.kubernetes_dashboard_readonly_cluster_token.data.token
    sensitive = true
}