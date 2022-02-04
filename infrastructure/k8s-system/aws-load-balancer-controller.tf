#################################
# AWS Load Balancer Controller  #
#################################
# https://kubernetes-sigs.github.io/aws-load-balancer-controller

locals {
  aws_load_balancer_controller_name              = "aws-load-balancer-controller"
  aws_load_balancer_controller_ingressclass_name = "alb"
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = local.aws_load_balancer_controller_name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.3.3"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.aws_load_balancer_controller_name
  }

  set {
    name  = "nameOverride"
    value = local.aws_load_balancer_controller_name
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.main.name
  }

  set {
    name  = "vpcId"
    value = data.aws_vpc.main.id
  }

  set {
    name  = "ingressClass"
    value = local.aws_load_balancer_controller_ingressclass_name
  }

  set {
    name  = "createIngressClassResource"
    value = false
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.service_system_medium_priority.metadata.0.name
  }

  values = [yamlencode({
    replicaCount = 1

    serviceAccount = {
      create = true
      name   = "${local.aws_load_balancer_controller_name}-sa"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller_assume_role.arn
      }
    }

    enableShield = false
    enableWaf    = false
    enableWafv2  = false

    resources = {
      limits = {
        cpu    = "50m"
        memory = "64Mi"
      }
      requests = {
        cpu    = "50m"
        memory = "64Mi"
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
                  values   = [local.aws_load_balancer_controller_name]
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
                  values   = [local.aws_load_balancer_controller_name]
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

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
    aws_ec2_tag.public_subnets_eks_elb,
    aws_ec2_tag.private_subnets_eks_elb
  ]
}

#################################
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "aws_load_balancer_controller" {
  metadata {
    name      = local.aws_load_balancer_controller_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.aws_load_balancer_controller_name
      "app.kubernetes.io/name"       = local.aws_load_balancer_controller_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.aws_load_balancer_controller_name
        "app.kubernetes.io/name"     = local.aws_load_balancer_controller_name
      }
    }
  }
}

#################################
# ISRA                          #
#################################

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:${local.aws_load_balancer_controller_name}-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "${var.environment}-${local.aws_load_balancer_controller_name}-assume-role"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller_assume_role.name
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.environment}-${local.aws_load_balancer_controller_name}"
  description = "AWS Load Balancer Controller for EKS Cluster ${var.environment}"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

#################################
# Subnet Auto Discovery         #
#################################
# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/deploy/subnet_discovery/

resource "aws_ec2_tag" "public_subnets_eks_elb" {
  count = length(data.aws_subnet_ids.public.ids)

  resource_id = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnets_eks_elb" {
  count = length(data.aws_subnet_ids.private.ids)

  resource_id = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

#################################
# Ingress Class                 #
#################################
# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/ingress/ingress_class/

resource "kubectl_manifest" "ingressclassparams_alb" {
  yaml_body = <<-EOF
    apiVersion: elbv2.k8s.aws/v1beta1
    kind: IngressClassParams
    metadata:
      name: ${local.aws_load_balancer_controller_ingressclass_name}
      labels:
        app.kubernetes.io/instance: ${local.aws_load_balancer_controller_name}
        app.kubernetes.io/name: ${local.aws_load_balancer_controller_name}
        app.kubernetes.io/managed-by: Terraform
    spec:
      group:
        name: default
      ipAddressType: dualstack
      scheme: internet-facing
    EOF

  // Requires IngressClassParams CRD 
  depends_on = [helm_release.aws_load_balancer_controller]
}

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = local.aws_load_balancer_controller_ingressclass_name
    labels = {
      "app.kubernetes.io/instance"   = local.aws_load_balancer_controller_name
      "app.kubernetes.io/name"       = local.aws_load_balancer_controller_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "false"
    }
  }
  spec {
    controller = "ingress.k8s.aws/alb"
    parameters {
      api_group = "elbv2.k8s.aws"
      kind      = "IngressClassParams"
      name      = kubectl_manifest.ingressclassparams_alb.name
    }
  }

  depends_on = [kubectl_manifest.ingressclassparams_alb]
}
