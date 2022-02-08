#################################
# EC2 Instance Profile          #
#################################

resource "aws_iam_instance_profile" "default" {
  name = "${var.environment}-default"
  role = aws_iam_role.instance_default.name

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role" "instance_default" {
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
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "instance_default_role_AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.instance_default.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "instance_default_role_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.instance_default.name
  policy_arn = data.aws_iam_policy.CloudWatchAgentServerPolicy.arn
}

data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
