# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "external-dns-controller-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks-cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks-cluster.arn]
      type        = "Federated"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "external-dns-controller-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.external-dns-controller-assume-role-policy.json
  name               = "${var.environment}-${var.module}-external-dns-controller-assume-role"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "external-dns-controller" {
  policy_arn = aws_iam_policy.external-dns-controller.arn
  role       = aws_iam_role.external-dns-controller-assume-role.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "external-dns-controller" {
  name = "${var.environment}-${var.module}-external-dns-controller"
  description = "EKS External DNS Controller for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.external-dns-controller.json
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "external-dns-controller" {
  statement {
    effect = "Allow"
    actions = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }  

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }  
}

output "external-dns-controller-role-arn" {
  value = aws_iam_role.external-dns-controller-assume-role.arn
}