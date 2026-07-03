variable "external_id" {
  type        = string
  description = "The unique connection token shown to you by Jungle Cleaner (looks like \"conn_...\"). Required — this is what ties the role to your account in our system and is enforced as the STS ExternalId condition on the trust policy."
}

variable "jungle_cleaner_account_id" {
  type        = string
  description = "The AWS account ID Jungle Cleaner uses to assume this role. You shouldn't need to change this."
  default     = "154959837717"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role Jungle Cleaner will assume."
  default     = "JungleCleanerReadOnly"
}

variable "api_url" {
  type        = string
  description = "Jungle Cleaner endpoint that receives the phone-home confirmation once the role exists. You shouldn't need to change this."
  default     = "https://junglecleaner.com/api/connect"
}

variable "enable_phone_home" {
  type        = bool
  description = "Best-effort: automatically notify Jungle Cleaner once the role is created, so the connection completes without you needing to paste the role ARN manually. Requires outbound HTTPS and curl on the machine running `terraform apply`. Purely a convenience — if it fails or is disabled, paste the `role_arn` output into the \"Verify manually\" box on the Jungle Cleaner connect page instead."
  default     = true
}
