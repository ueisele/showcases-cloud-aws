#################################
# EKS IAM Auth Controller       #
#################################
# https://github.com/rustrial/aws-eks-iam-auth-controller

locals {
  aws_eks_im_auth_controller_name = "aws-eks-iam-auth-controller"
}

resource "helm_release" "aws_eks_iam_auth_controller" {
  name       = local.aws_eks_im_auth_controller_name
  repository = "https://rustrial.github.io/aws-eks-iam-auth-controller"
  chart      = "rustrial-aws-eks-iam-auth-controller"
  version    = "0.1.6"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.aws_eks_im_auth_controller_name
  }

  set {
    name  = "nameOverride"
    value = local.aws_eks_im_auth_controller_name
  }

  values = [yamlencode({
    resources = {
      limits = {
        cpu    = "10m"
        memory = "16Mi"
      }
      requests = {
        cpu    = "10m"
        memory = "16Mi"
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
    }
  })]
}

#################################
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "aws_eks_iam_auth_controller" {
  metadata {
    name      = local.aws_eks_im_auth_controller_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.aws_eks_im_auth_controller_name
      "app.kubernetes.io/name"       = local.aws_eks_im_auth_controller_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.aws_eks_im_auth_controller_name
        "app.kubernetes.io/name"     = local.aws_eks_im_auth_controller_name
      }
    }
  }
}

#################################
# IAM Identity Mappings         #
#################################
# kubernetes_manifest resource cannot be used because of
# https://github.com/hashicorp/terraform-provider-kubernetes/pull/1506

resource "kubectl_manifest" "iamidentitymapping_role_eks_node_group" {
  yaml_body = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-eks-node-group
      namespace: kube-system
      labels:
        app.kubernetes.io/managed-by: Terraform
    spec:
      arn: ${data.aws_iam_role.eks_node_group.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
      - system:bootstrappers
      - system:nodes
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.aws_eks_iam_auth_controller]
}

resource "kubectl_manifest" "iamidentitymapping_role_eks_fargate_profile" {
  yaml_body = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-eks-fargate-profile
      namespace: kube-system
      labels:
        app.kubernetes.io/managed-by: Terraform
    spec:
      arn: ${data.aws_iam_role.eks_fargate_profile.arn}
      username: system:node:{{SessionName}}
      groups:
      - system:bootstrappers
      - system:nodes
      - system:node-proxier
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.aws_eks_iam_auth_controller]
}

resource "kubectl_manifest" "iamidentitymapping_role_k8sadmin" {
  yaml_body = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-k8sadmin
      namespace: kube-system
      labels:
        app.kubernetes.io/managed-by: Terraform
    spec:
      arn: ${data.aws_iam_role.k8sadmin.arn}
      username: admin
      groups:
      - system:masters
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.aws_eks_iam_auth_controller]
}

resource "kubectl_manifest" "iamidentitymapping_admin_users" {
  count = length(var.k8s_admin_users)

  yaml_body = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-k8sadmin-${element(var.k8s_admin_users, count.index)}
      namespace: kube-system
      labels:
        app.kubernetes.io/managed-by: Terraform
    spec:
      arn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${element(var.k8s_admin_users, count.index)}
      username: admin
      groups:
      - system:masters
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.aws_eks_iam_auth_controller]
}
