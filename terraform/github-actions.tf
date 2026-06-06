data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_actions_role_name_sanitized = startswith(var.github_actions_role_name, "arn:aws:iam::") ? regexreplace(var.github_actions_role_name, "^arn:aws:iam::[0-9]+:role/", "") : var.github_actions_role_name
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.github_actions_oidc_provider_arn == "" ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = local.tags
}

locals {
  github_actions_oidc_provider_arn = var.github_actions_oidc_provider_arn != "" ? var.github_actions_oidc_provider_arn : aws_iam_openid_connect_provider.github_actions[0].arn
}

data "aws_iam_policy_document" "github_actions_terraform_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.github_actions_oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_actions_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_terraform" {
  name               = local.github_actions_role_name_sanitized
  assume_role_policy = data.aws_iam_policy_document.github_actions_terraform_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = var.github_actions_role_policy_arn
}

# Grant the GitHub Actions role access to the EKS cluster
resource "aws_eks_access_entry" "github_actions" {
  count = var.cluster_name != "" ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions_terraform.arn
  type          = "STANDARD"
  user_name     = local.github_actions_role_name_sanitized
  tags          = local.tags

  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
  }
}

# Grant cluster-admin permissions to the GitHub Actions role
resource "aws_eks_access_policy_association" "github_actions_admin" {
  count = var.cluster_name != "" ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions_terraform.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_actions]
}
