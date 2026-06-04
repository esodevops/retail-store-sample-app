data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_actions_role_name_sanitized = contains(var.github_actions_role_name, "arn:aws:iam::") ? regexreplace(var.github_actions_role_name, "^arn:aws:iam::[0-9]+:role/", "") : var.github_actions_role_name
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
      values = [
        "repo:${var.github_actions_repository}:ref:refs/heads/main",
        "repo:${var.github_actions_repository}:pull_request",
      ]
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
