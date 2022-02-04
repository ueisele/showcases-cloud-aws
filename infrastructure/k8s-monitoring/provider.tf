provider "aws" {
  region  = var.region
  profile = var.profile

  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}
