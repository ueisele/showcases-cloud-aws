#################################
# EKS Cluster Security Groups   #
#################################

resource "aws_security_group" "eks_cluster" {
  name        = "${var.environment}-eks-cluster"
  description = "Cluster communication with EKS worker nodes"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-eks-cluster"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_security_group_rule" "eks_cluster_nodes_ingress" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_node_group.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_cluster_nodes_egress" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 1024
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_node_group.id
  to_port                  = 65535
  type                     = "egress"
}

##################################
# EKS Node Group Security Groups #
##################################

resource "aws_security_group" "eks_node_group" {
  name        = "${var.environment}-eks-node-group"
  description = "Security group for all nodes in the cluster"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-eks-node-group"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ec2_tag" "sg_eks_node_group" {
  resource_id = aws_security_group.eks_node_group.id
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "owned"
}

# Egress

resource "aws_security_group_rule" "eks_node_group_nodes_egress" {
  description              = "Allow nodes to communicate with each other"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "egress"
  source_security_group_id = aws_security_group.eks_node_group.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "eks_node_group_private_egress" {
  description              = "Allow outbound to private subnets"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "egress"
  source_security_group_id = tolist(data.aws_security_groups.private.ids)[0]
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "eks_node_group_internet_egress_http" {
  description       = "Allow HTTP to Internet"
  security_group_id = aws_security_group.eks_node_group.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "eks_node_group_internet_egress_https" {
  description       = "Allow HTTPS to Internet"
  security_group_id = aws_security_group.eks_node_group.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

resource "aws_security_group_rule" "eks_node_group_internet_egress_dns" {
  description       = "Allow DNS to Internet"
  security_group_id = aws_security_group.eks_node_group.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = 53
  to_port           = 53
  protocol          = "-1"
}

# Ingress

resource "aws_security_group_rule" "eks_node_group_nodes_ingress" {
  description              = "Allow nodes to communicate with each other"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "ingress"
  source_security_group_id = aws_security_group.eks_node_group.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "eks_node_group_cluster_ingress" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "ingress"
  source_security_group_id = aws_security_group.eks_cluster.id
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "eks_node_group_private_ingress" {
  description              = "Allow inbound from private subnets"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "ingress"
  source_security_group_id = tolist(data.aws_security_groups.private.ids)[0]
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "eks_node_group_public_ingress" {
  description              = "Allow inbound from public subnets"
  security_group_id        = aws_security_group.eks_node_group.id
  type                     = "ingress"
  source_security_group_id = tolist(data.aws_security_groups.public.ids)[0]
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}
