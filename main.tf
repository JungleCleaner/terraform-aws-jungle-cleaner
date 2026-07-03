data "aws_caller_identity" "current" {}

# ── Read-only IAM role ───────────────────────────────────────────────────────
# Mirrors the CloudFormation template Jungle Cleaner's web onboarding flow
# deploys (infra/templates/jungle-cleaner-role.yaml in the main app repo) —
# same trust policy, same managed policy, same inline policies. Unlike that
# template, this module doesn't need a self-deleting Lambda/custom-resource:
# Terraform state isn't visible in the AWS console the way a permanent
# CloudFormation stack would be, so there's nothing to "clean up" here.
resource "aws_iam_role" "jungle_cleaner" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.jungle_cleaner_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "JungleCleaner"
  }

  # Mirrors the CloudFormation template's `DeletionPolicy: Retain` — a stray
  # `terraform destroy` shouldn't silently revoke Jungle Cleaner's access.
  # Remove this role via the Jungle Cleaner dashboard, then run
  # `terraform state rm aws_iam_role.jungle_cleaner` before destroying.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "read_only_access" {
  role       = aws_iam_role.jungle_cleaner.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "extra_read_only" {
  name = "ExtraReadOnly"
  role = aws_iam_role.jungle_cleaner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:*",
          "cost-optimization-hub:GetRecommendation",
          "cost-optimization-hub:ListRecommendations",
          "cost-optimization-hub:ListRecommendationSummaries",
          "compute-optimizer:GetRecommendationSummaries",
          "compute-optimizer:GetEC2InstanceRecommendations",
          "compute-optimizer:GetLambdaFunctionRecommendations",
          "waf:ListWebACLs",
          "waf:ListResourcesForWebACL",
          "waf-regional:ListWebACLs",
          "waf-regional:ListResourcesForWebACL",
          "quicksight:ListUsers"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "enable_cost_services" {
  name = "EnableCostServices"
  role = aws_iam_role.jungle_cleaner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OptInComputeOptimizer"
        Effect   = "Allow"
        Action   = "compute-optimizer:UpdateEnrollmentStatus"
        Resource = "*"
      },
      {
        Sid      = "OptInCostOptimizationHub"
        Effect   = "Allow"
        Action   = ["cost-optimization-hub:UpdateEnrollmentStatus"]
        Resource = "*"
      },
      {
        Sid      = "EnableCOHOrgAccess"
        Effect   = "Allow"
        Action   = ["organizations:EnableAWSServiceAccess"]
        Resource = "*"
        Condition = {
          StringLike = {
            "organizations:ServicePrincipal" = ["cost-optimization-hub.bcm.amazonaws.com"]
          }
        }
      },
      {
        Sid      = "CreateCOHServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "cost-optimization-hub.bcm.amazonaws.com"
          }
        }
      },
      {
        Sid      = "CreateComputeOptimizerServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/compute-optimizer.amazonaws.com/*"
      },
      {
        Sid    = "PatchServiceLinkedRoles"
        Effect = "Allow"
        Action = "iam:PutRolePolicy"
        Resource = [
          "arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/*"
        ]
      }
    ]
  })
}

# ── Best-effort phone-home ───────────────────────────────────────────────────
# Purely a convenience: lets `terraform apply` finish the connection
# automatically, the same way the CloudFormation template's Lambda does. This
# is intentionally best-effort (never fails the apply) because it depends on
# things Terraform can't guarantee — curl being present, outbound HTTPS
# access from wherever `apply` runs (a laptop, CI, Terraform Cloud, etc.). If
# it doesn't work, paste the `role_arn` output into the "Verify manually" box
# on the Jungle Cleaner connect page instead — that path re-verifies the role
# the same way (an actual `sts:AssumeRole` call), so it's equally trustworthy.
resource "null_resource" "phone_home" {
  count = var.enable_phone_home ? 1 : 0

  triggers = {
    role_arn = aws_iam_role.jungle_cleaner.arn
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      curl -sS -m 10 -X POST "${var.api_url}" \
        -H "Content-Type: application/json" \
        -d "{\"token\":\"${var.external_id}\",\"roleArn\":\"${aws_iam_role.jungle_cleaner.arn}\",\"accountId\":\"${data.aws_caller_identity.current.account_id}\"}" \
        || true
    EOT
  }

  depends_on = [
    aws_iam_role.jungle_cleaner,
    aws_iam_role_policy_attachment.read_only_access,
    aws_iam_role_policy.extra_read_only,
    aws_iam_role_policy.enable_cost_services
  ]
}
