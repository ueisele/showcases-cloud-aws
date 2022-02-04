#################################
# EKS Cluster                   #
#################################

resource "aws_eks_cluster" "main" {
  name     = var.environment
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    subnet_ids              = data.aws_subnet_ids.private.ids
    security_group_ids      = [aws_security_group.eks_cluster.id, aws_security_group.eks_node_group.id]
  }

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController,
  ]
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.environment}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

#################################
# VPC Tags                      #
#################################

resource "aws_ec2_tag" "vpc_eks_cluster" {
  resource_id = data.aws_vpc.main.id
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnets_eks_cluster" {
  count = length(data.aws_subnet_ids.public.ids)

  resource_id = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnets_eks_cluster" {
  count = length(data.aws_subnet_ids.private.ids)

  resource_id = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "shared"
}

#################################
# EKS Fargate Profile           #
#################################

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${aws_eks_cluster.main.name}-default"
  pod_execution_role_arn = aws_iam_role.eks_fargate_profile.arn
  subnet_ids             = data.aws_subnet_ids.private.ids

  selector {
    namespace = "default"
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_profile_AmazonEKSFargatePodExecutionRolePolicy,
  ]
}

resource "aws_iam_role" "eks_fargate_profile" {
  name = "${aws_eks_cluster.main.name}-eks-fargate-profile"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_fargate_profile_AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_profile.name
}

output "eks_fargate_profile_role_arn" {
  value = aws_iam_role.eks_fargate_profile.arn
}

#################################
# EKS Node Groups               #
#################################
# Example custom launch template: # https://github.com/aws-samples/amazon-eks-bottlerocket-mngnodegrp-terraform/blob/main/launch_template.tf

resource "aws_eks_node_group" "small_arm64" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${aws_eks_cluster.main.name}-small-arm64"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = data.aws_subnet_ids.private.ids

  ami_type       = "BOTTLEROCKET_ARM_64"
  instance_types = ["t4g.small"]
  disk_size      = 20

  scaling_config {
    max_size     = 9
    min_size     = 1
    desired_size = 3
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  update_config {
    max_unavailable = 2
  }

  tags = {
    Environment                                              = var.environment
    Terraform                                                = "true"
    "k8s.io/cluster-autoscaler/enabled"                      = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "small_amd64" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${aws_eks_cluster.main.name}-small-amd64"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = data.aws_subnet_ids.private.ids

  ami_type       = "BOTTLEROCKET_x86_64"
  instance_types = ["t3a.small"]
  disk_size      = 20

  scaling_config {
    max_size     = 9
    min_size     = 0
    desired_size = 0
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  update_config {
    max_unavailable = 2
  }

  tags = {
    Environment                                              = var.environment
    Terraform                                                = "true"
    "k8s.io/cluster-autoscaler/enabled"                      = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "medium_arm64" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${aws_eks_cluster.main.name}-medium-arm64"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = data.aws_subnet_ids.private.ids

  ami_type       = "BOTTLEROCKET_ARM_64"
  instance_types = ["t4g.medium"]
  disk_size      = 20

  scaling_config {
    max_size     = 9
    min_size     = 0
    desired_size = 0
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  update_config {
    max_unavailable = 2
  }

  tags = {
    Environment                                              = var.environment
    Terraform                                                = "true"
    "k8s.io/cluster-autoscaler/enabled"                      = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "medium_amd64" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${aws_eks_cluster.main.name}-medium-amd64"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = data.aws_subnet_ids.private.ids

  ami_type       = "BOTTLEROCKET_x86_64"
  instance_types = ["t3a.medium"]
  disk_size      = 20

  scaling_config {
    max_size     = 9
    min_size     = 0
    desired_size = 0
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  update_config {
    max_unavailable = 2
  }

  tags = {
    Environment                                              = var.environment
    Terraform                                                = "true"
    "k8s.io/cluster-autoscaler/enabled"                      = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# IAM

resource "aws_iam_role" "eks_node_group" {
  name = "${var.environment}-eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    Name        = "${var.environment}-eks-node-group"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group.name
}

output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}

#############################################
# EKS IRSA (IAM Roles for Service Accounts) #
#############################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster#enabling-iam-roles-for-service-accounts

data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.environment}-eks-cluster-irsa"
    Environment = var.environment
    Terraform   = "true"
  }
}

#################################
# EKS Addons                    #
#################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon

# VPC-CNI
# https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html

data "aws_iam_policy_document" "eks_vpn_cni_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_vpn_cni_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_vpn_cni_assume_role_policy.json
  name               = "${var.environment}-eks-vpn-cni-assume-role"
}

resource "aws_iam_role_policy_attachment" "vpn_cni_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_vpn_cni_assume_role.name
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.eks_vpn_cni_assume_role.arn
  resolve_conflicts        = "OVERWRITE"
  tags = {
    eks_addon   = "vpc-cni"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Kube-Proxy
# https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html

resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "kube-proxy"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon   = "kube-proxy"
    Environment = var.environment
    Terraform   = "true"
  }
}

# CoreDNS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon

resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon   = "coredns"
    Environment = var.environment
    Terraform   = "true"
  }
}
