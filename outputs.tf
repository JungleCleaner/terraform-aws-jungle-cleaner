output "role_arn" {
  description = "ARN of the read-only IAM role. Paste this into the \"Verify manually\" box on your Jungle Cleaner connect page if the automatic phone-home didn't complete the connection."
  value       = aws_iam_role.jungle_cleaner.arn
}

output "account_id" {
  description = "The AWS account ID this role was created in."
  value       = data.aws_caller_identity.current.account_id
}
