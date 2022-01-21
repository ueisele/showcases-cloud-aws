#################################
# EC2 Instance Profile          #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "default" {
  name  = "${var.environment}-default"
  role  = aws_iam_role.instance-default.name

  tags = {
    Environment = var.environment
    Terraform = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "instance-default" {
  name = "${var.environment}-instance-default"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "instance-default-role-AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.instance-default.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "instance-default-role-CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.instance-default.name
  policy_arn = data.aws_iam_policy.CloudWatchAgentServerPolicy.arn
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy
data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
