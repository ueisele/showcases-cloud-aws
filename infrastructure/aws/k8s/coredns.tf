#################################
# CoreDNS                       #
#################################
# https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
resource "aws_eks_addon" "coredns" {
  cluster_name      = data.aws_eks_cluster.main.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "coredns"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}