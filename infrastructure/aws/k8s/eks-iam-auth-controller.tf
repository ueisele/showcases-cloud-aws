#################################
# EKS IAM Auth Controller       #
#################################
# https://github.com/rustrial/aws-eks-iam-auth-controller

resource "helm_release" "eks-iam-auth-controller" {
  name       = "eks-iam-auth-controller"
  repository = "https://rustrial.github.io/aws-eks-iam-auth-controller"
  chart      = "rustrial-aws-eks-iam-auth-controller"
  version    = "0.1.6"

  namespace  = "kube-system"

  set {
    name = "fullnameOverride"
    value = "eks-iam-auth-controller"
  }

  set {
    name = "nameOverride"
    value = "eks-iam-auth-controller"
  }

  values = [yamlencode({
    resources = {
      limits = {
        cpu = "100m"
        memory = "32Mi"
      }
      requests = {
        cpu = "50m"
        memory = "32Mi"
      }
    }

    tolerations = [{
      key = "system"
      operator = "Equal"
      value = "true"
      effect = "NoSchedule"
    }]

    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [
              {
                key = "eks.amazonaws.com/nodegroup"
                operator = "In"
                values = [local.eks_cluster_system_node_group_name]
              },
              {
                key = "kubernetes.io/os"
                operator = "In"
                values = ["linux"]
              },
              {
                key = "kubernetes.io/arch"
                operator = "In"
                values = ["amd64","arm64"]
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
                  key = "app.kubernetes.io/name"
                  operator = "In"
                  values = ["eks-iam-auth-controller"]
                }]
              }
              topologyKey = "kubernetes.io/hostname"
            }
            weight = 100
          },
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key = "app.kubernetes.io/name"
                  operator = "In"
                  values = ["eks-iam-auth-controller"]
                }]
              }
              topologyKey = "failure-domain.beta.kubernetes.io/zone"
            }
            weight = 100
          }
        ]
      }
    }
  })]
}

#################################
# IAM Identity Mappings         #
#################################
# kubernetes_manifest resource cannot be used because of
# https://github.com/hashicorp/terraform-provider-kubernetes/pull/1506

resource "kubectl_manifest" "iamidentitymapping-role-eks-node-group" {
  yaml_body  = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-eks-node-group
      namespace: kube-system
    spec:
      arn: ${data.aws_iam_role.eks-node-group.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
      - system:bootstrappers
      - system:nodes
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.eks-iam-auth-controller]
}

resource "kubectl_manifest" "iamidentitymapping-role-eks-fargate-profile" {
  yaml_body  = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-eks-fargate-profile
      namespace: kube-system
    spec:
      arn: ${data.aws_iam_role.eks-fargate-profile.arn}
      username: system:node:{{SessionName}}
      groups:
      - system:bootstrappers
      - system:nodes
      - system:node-proxier
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.eks-iam-auth-controller]
}

resource "kubectl_manifest" "iamidentitymapping-role-k8sadmin" {
  yaml_body  = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-k8sadmin
      namespace: kube-system
    spec:
      arn: ${data.aws_iam_role.k8sadmin.arn}
      username: admin
      groups:
      - system:masters
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.eks-iam-auth-controller]
}

resource "kubectl_manifest" "iamidentitymapping-admin-users" {
  count = length(var.k8s_admin_users)

  yaml_body  = <<-EOF
    apiVersion: iamauthenticator.k8s.aws/v1alpha1
    kind: IAMIdentityMapping
    metadata:
      name: role-k8sadmin-${element(var.k8s_admin_users, count.index)}
      namespace: kube-system
    spec:
      arn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${element(var.k8s_admin_users, count.index)}
      username: admin
      groups:
      - system:masters
    EOF

  // Requires IAMIdentityMapping CRD 
  depends_on = [helm_release.eks-iam-auth-controller]
}
