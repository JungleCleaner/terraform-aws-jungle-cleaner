# terraform-aws-jungle-cleaner

Connect your AWS account to [Jungle Cleaner](https://junglecleaner.com) — a
read-only cost-saving finder that tells you in plain English what you're
wasting money on ("you have a database that hasn't been queried in 30 days,
costing $43/mo") instead of making you dig through the AWS console. Results
land in your dashboard or straight in your AI tool via MCP — no jargon, no
deletion features, just the findings so you (or your AI agent) can decide
what to clean up.

This module creates a single IAM role in your account, scoped almost
entirely to read-only access — plus a handful of narrow, one-time write
permissions solely to opt you into two free AWS recommendation services
(Compute Optimizer, Cost Optimization Hub), which require opt-in before
they'll return anything. Nothing this role can do touches, modifies, or
deletes your actual infrastructure — see [What this creates](#what-this-creates)
for the exact breakdown.

## Usage

Get your `external_id` token from [junglecleaner.com](https://junglecleaner.com)
— either the sign-up flow on the dashboard, or the `connect_aws` tool if
you're connecting from an AI tool like Cursor or Claude Code via MCP.

The fastest way to get connected — clone this repo and apply it directly, no
file editing required:

```sh
git clone https://github.com/JungleCleaner/terraform-aws-jungle-cleaner.git
cd terraform-aws-jungle-cleaner
terraform init
terraform apply -var="external_id=conn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

(Works the same way with [OpenTofu](https://opentofu.org) — swap `terraform`
for `tofu`.)

If you'd rather manage this as part of your existing Terraform-managed AWS
account instead of a standalone `apply`, reference it as a module:

```hcl
module "jungle_cleaner" {
  source = "JungleCleaner/jungle-cleaner/aws"

  external_id = "conn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Once applied, this module makes a best-effort attempt to notify Jungle
Cleaner automatically so your dashboard shows the account as connected
within a minute. If that doesn't happen — no outbound network access from
wherever you ran `apply`, no `curl` available, etc. — copy the `role_arn`
output and paste it into the "Verify manually" box on your Jungle Cleaner
connect page. That path independently re-verifies the role by actually
assuming it, so it's just as trustworthy either way.

## What this creates

- One IAM role (`JungleCleanerReadOnly` by default) trusting Jungle
  Cleaner's AWS account, gated by an `sts:ExternalId` condition tied to your
  connection token — nobody else can assume it even if they somehow learned
  the role's ARN.
- The AWS-managed `ReadOnlyAccess` policy, plus a small number of extra
  read-only actions (Cost Explorer, Compute Optimizer, Cost Optimization
  Hub, WAF Classic, QuickSight).
- A narrow set of **write** actions — the only ones this role has —
  needed solely to opt your account into two free AWS services that
  require enrollment before they'll return anything:
  `compute-optimizer:UpdateEnrollmentStatus`,
  `cost-optimization-hub:UpdateEnrollmentStatus`,
  `organizations:EnableAWSServiceAccess` (scoped to the Cost Optimization
  Hub service principal only), and `iam:CreateServiceLinkedRole` /
  `iam:PutRolePolicy` (scoped to the Compute Optimizer and Cost
  Optimization Hub service-linked roles only). None of these can create,
  modify, or delete anything in your actual infrastructure (EC2, S3, RDS,
  etc.) — see [`main.tf`](./main.tf) for the exact statements.
- Nothing else. No Lambdas, no S3 buckets, no other roles.

See [`main.tf`](./main.tf) for the exact policy documents — same as the
[CloudFormation template](https://github.com/JungleCleaner/aws-cost-saver)
Jungle Cleaner's web onboarding uses, so both onboarding paths grant
identical access.

## Inputs

| Name | Description | Default |
|---|---|---|
| `external_id` | Your connection token from Jungle Cleaner. Required. | — |
| `jungle_cleaner_account_id` | AWS account ID Jungle Cleaner assumes this role from. | `154959837717` |
| `role_name` | Name of the created IAM role. | `JungleCleanerReadOnly` |
| `api_url` | Endpoint the best-effort phone-home step notifies. | `https://junglecleaner.com/api/connect` |
| `enable_phone_home` | Attempt to auto-confirm the connection on apply. | `true` |

## Outputs

| Name | Description |
|---|---|
| `role_arn` | ARN of the created role — paste into the manual verify box if needed. |
| `account_id` | Your AWS account ID. |

## Removing access

Delete the IAM role (`aws_iam_role.jungle_cleaner`, `role_name` by default)
from the [Jungle Cleaner dashboard](https://junglecleaner.com/dashboard) or
directly in IAM — that's the only resource this module leaves behind. The
role has `prevent_destroy` set, so `terraform destroy` won't remove it by
itself; run `terraform state rm aws_iam_role.jungle_cleaner` (and the
associated policy resources) first if you want `destroy` to succeed after
removing access another way.

## Related

- [junglecleaner.com](https://junglecleaner.com) — the app itself
- [JungleCleaner/aws-cleanup-scripts](https://github.com/JungleCleaner/aws-cleanup-scripts) — remediation scripts referenced in findings
