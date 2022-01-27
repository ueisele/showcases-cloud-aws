# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool
resource "aws_cognito_user_pool" "main" {
  name = var.environment

  alias_attributes = ["email", "preferred_username"]

  username_configuration {
    case_sensitive = false
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.environment}-${replace(replace(var.route53_public_main_zone, ".", "-"), "aws-", "")}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client
resource "aws_cognito_user_pool_client" "main" {
  name         = var.environment
  user_pool_id = aws_cognito_user_pool.main.id

  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["https://*.${data.aws_route53_zone.public.name}/oauth2/idpresponse", "https://nginx-hello.showcase.aws.uweeisele.dev/oauth2/idpresponse"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  generate_secret = true
}

output "user-pool-arn" {
  value = aws_cognito_user_pool.main.arn
}

output "user-pool-domain" {
  value = aws_cognito_user_pool_domain.main.domain
}

output "user-pool-client-id" {
  value = aws_cognito_user_pool_client.main.id
}

output "user-pool-client-secret" {
  value     = aws_cognito_user_pool_client.main.client_secret
  sensitive = true
}
