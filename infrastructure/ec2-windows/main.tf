#################################
# Windows EC2 (Local)           #
#################################

## AMI

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

## IAM

resource "aws_iam_role" "ec2_windows_ssm_role" {
  name = "${var.environment}-ec2-windows-ssm-role"
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

resource "aws_iam_role_policy_attachment" "ec2_windows_ssm_role_AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.ec2_windows_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_windows_ssm_role_AmazonSSMDirectoryServiceAccess" {
  role       = aws_iam_role.ec2_windows_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_instance_profile" "ec2_windows_ssm_role_profile" {
  name = "${var.environment}-ec2-windows-ssm-role-profile"
  role = aws_iam_role.ec2_windows_ssm_role.name
}

## Security Group

resource "aws_security_group" "windows" {
  name        = "${var.environment}-windows"
  description = "Security group for Windows EC2 instances"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-windows"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Ingress

resource "aws_security_group_rule" "windows_rdp" {
  description       = "Allow RDP ingress to Windows instances"
  security_group_id = aws_security_group.windows.id
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

# Egress

resource "aws_security_group_rule" "windows_open_egress" {
  description       = "Allow any egress for Windows instances"
  security_group_id = aws_security_group.windows.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

## Key

resource "tls_private_key" "ec2_windows" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_windows" {
  key_name   = var.environment
  public_key = tls_private_key.ec2_windows.public_key_openssh
}

resource "local_file" "ec2_windows_private_key" {
  filename = "out/id_rsa.pem"
  content  = tls_private_key.ec2_windows.private_key_pem
}

resource "local_file" "ec2_windows_public_key" {
  filename = "out/id_rsa.pub"
  content  = tls_private_key.ec2_windows.public_key_openssh
}

#################################
# Windows EC2 (Local)           #
#################################

resource "aws_instance" "local" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3a.small"

  key_name          = aws_key_pair.ec2_windows.key_name
  get_password_data = true

  iam_instance_profile = aws_iam_instance_profile.ec2_windows_ssm_role_profile.name

  subnet_id              = tolist(data.aws_subnet_ids.public.ids)[0]
  vpc_security_group_ids = [aws_security_group.windows.id]

  associate_public_ip_address = true

  tags = {
    Name        = "${var.environment}-local-ldap-admin"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ssm_document" "local_ldap_domain_join" {
  name          = "${var.environment}-local-ldap-join-domain"
  document_type = "Command"
  content       = <<-DOC
    {
        "schemaVersion": "1.0",
        "description": "Automatic Domain Join Configuration",
        "runtimeConfig": {
            "aws:domainJoin": {
                "properties": {
                    "directoryId": "${data.aws_directory_service_directory.local.id}",
                    "directoryName": "${data.aws_directory_service_directory.local.name}",
                    "dnsIpAddresses": ${jsonencode(data.aws_directory_service_directory.local.dns_ip_addresses)}
                }
            }
        }
    }
    DOC
}

resource "aws_ssm_association" "local_windows_local_ldap_domain_join" {
  name        = aws_ssm_document.local_ldap_domain_join.name
  instance_id = aws_instance.local.id
}

output "local_windows_public_dns" {
  value = aws_instance.local.public_dns
}

output "local_windows_username" {
  value = "Administrator"
}

output "local_windows_password" {
  value     = rsadecrypt(aws_instance.local.password_data, tls_private_key.ec2_windows.private_key_pem)
  sensitive = true
}

#################################
# Windows EC2 (Remote)          #
#################################

resource "aws_instance" "remote" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3a.small"

  key_name          = aws_key_pair.ec2_windows.key_name
  get_password_data = true

  iam_instance_profile = aws_iam_instance_profile.ec2_windows_ssm_role_profile.name

  subnet_id              = tolist(data.aws_subnet_ids.public.ids)[0]
  vpc_security_group_ids = [aws_security_group.windows.id]

  associate_public_ip_address = true

  tags = {
    Name        = "${var.environment}-remote-ldap-admin"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ssm_document" "remote_ldap_domain_join" {
  name          = "${var.environment}-remote-ldap-join-domain"
  document_type = "Command"
  content       = <<-DOC
    {
        "schemaVersion": "1.0",
        "description": "Automatic Domain Join Configuration",
        "runtimeConfig": {
            "aws:domainJoin": {
                "properties": {
                    "directoryId": "${data.aws_directory_service_directory.remote.id}",
                    "directoryName": "${data.aws_directory_service_directory.remote.name}",
                    "dnsIpAddresses": ${jsonencode(data.aws_directory_service_directory.remote.dns_ip_addresses)}
                }
            }
        }
    }
    DOC
}

resource "aws_ssm_association" "remote_windows_remote_ldap_domain_join" {
  name        = aws_ssm_document.remote_ldap_domain_join.name
  instance_id = aws_instance.remote.id
}

output "remote_windows_public_dns" {
  value = aws_instance.remote.public_dns
}

output "remote_windows_username" {
  value = "Administrator"
}

output "remote_windows_password" {
  value     = rsadecrypt(aws_instance.remote.password_data, tls_private_key.ec2_windows.private_key_pem)
  sensitive = true
}
