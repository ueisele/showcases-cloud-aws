#################################
# AWS Load Balancer Controller  #
#################################
# https://kubernetes-sigs.github.io/aws-load-balancer-controller

resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.3.3"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "nameOverride"
    value = "aws-load-balancer-controller"
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
    value = "alb"
  }

  set {
    name  = "createIngressClassResource"
    value = false
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.medium-priority-system-service.metadata.0.name
  }

  values = [yamlencode({
    replicaCount = 1

    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller-sa"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws-lb-controller-assume-role.arn
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
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["aws-load-balancer-controller"]
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
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["aws-load-balancer-controller"]
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
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "aws-load-balancer-controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "aws-load-balancer-controller"
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = "aws-load-balancer-controller"
        "app.kubernetes.io/name"     = "aws-load-balancer-controller"
      }
    }
  }
}

#################################
# ISRA                          #
#################################

data "aws_iam_policy_document" "aws-lb-controller-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws-lb-controller-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.aws-lb-controller-assume-role-policy.json
  name               = "${var.environment}-${var.module}-aws-lb-controller-assume-role"
}

resource "aws_iam_role_policy_attachment" "aws-lb-controller" {
  policy_arn = aws_iam_policy.aws-lb-controller.arn
  role       = aws_iam_role.aws-lb-controller-assume-role.name
}

resource "aws_iam_policy" "aws-lb-controller" {
  name        = "${var.environment}-${var.module}-aws-lb-controller"
  description = "EKS AWS Load Balancer Controller for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.aws-lb-controller.json
}

data "aws_iam_policy_document" "aws-lb-controller" {
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

resource "aws_ec2_tag" "public-subnets-eks-elb" {
  count = length(data.aws_subnet_ids.public.ids)

  resource_id = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private-subnets-eks-elb" {
  count = length(data.aws_subnet_ids.private.ids)

  resource_id = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

#################################
# Ingress Class                 #
#################################
# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/ingress/ingress_class/

resource "kubectl_manifest" "ingressclassparams-alb" {
  yaml_body = <<-EOF
    apiVersion: elbv2.k8s.aws/v1beta1
    kind: IngressClassParams
    metadata:
      name: alb
      labels:
        app.kubernetes.io/instance: aws-load-balancer-controller
        app.kubernetes.io/name: aws-load-balancer-controller
        app.kubernetes.io/managed-by: Terraform
    spec:
      group:
        name: default
      ipAddressType: dualstack
      scheme: internet-facing
    EOF

  // Requires IngressClassParams CRD 
  depends_on = [helm_release.aws-load-balancer-controller]
}

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = "alb"
    labels = {
      "app.kubernetes.io/instance" = "aws-load-balancer-controller"
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
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
      name      = kubectl_manifest.ingressclassparams-alb.name
    }
  }

  depends_on = [kubectl_manifest.ingressclassparams-alb]
}
