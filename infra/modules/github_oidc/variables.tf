variable "role_name" {
  description = "IAM role name for GitHub Actions."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "allowed_subjects" {
  description = "Accepted GitHub OIDC subject claims."
  type        = list(string)
}

variable "policy_json" {
  description = "Inline IAM policy document for the GitHub deploy role."
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create the shared GitHub Actions OIDC provider in this stack."
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN when not creating one here."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
