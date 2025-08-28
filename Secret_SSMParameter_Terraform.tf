variable "MDMDomainNameOrIP" {
  description = "MDM domain name or IP address"
  type        = string
  sensitive   = false
}

variable "MDMEnrollmentUser" {
  description = "MDM API username or client ID with privileges to create computer invitations."
  type        = string
  sensitive   = false
}

variable "MDMEnrollmentUserPassword" {
  description = "Password for MDM user or client secret with privileges to create computer invitations."
  type        = string
  sensitive   = true
}

variable "LocalAdmin" {
  description = "Local administrator account."
  type        = string
  default     = "ec2-user"
  sensitive   = false
}

variable "LocalAdminPassword" {
  description = "Local administrator account password."
  type        = string
  sensitive   = true
}

resource "aws_ssm_parameter" "mdmCredentialsTF" {
  name = "mdmCredentialsTF"
  type        = "String"
#   If using the non-default key for the region, uncomment below and replace with your key ID.
#   key_id = "replace_with_kms_key_id"
  value = <<EOF
{"mdmServerDomain":"${var.MDMDomainNameOrIP}","mdmEnrollmentUser":"${var.MDMEnrollmentUser}","mdmEnrollmentPassword":"${var.MDMEnrollmentUserPassword}","localAdmin":"${var.LocalAdmin}","localAdminPassword":"${var.LocalAdminPassword}"}
EOF
}

data "aws_iam_policy_document" "mdmCredentialAccessPolicyDoc" {
  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:GetParameterHistory"
    ]
    resources = [
      aws_ssm_parameter.mdmCredentialsTF.arn
    ]
  }
}

resource "aws_iam_role" "mdmCredentialAccessRole" {
  name               = "mdmCredentialAccessRole"
  assume_role_policy = data.aws_iam_policy_document.mdmCredentialAssumeRole.json
}

data "aws_iam_policy_document" "mdmCredentialAssumeRole" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "mdmCredentialAccess" {
  name   = "mdmCredentialAccess"
  policy = data.aws_iam_policy_document.mdmCredentialAccessPolicyDoc.json
}

resource "aws_iam_role_policy_attachment" "mdmCredentialAccessAttach" {
  role       = aws_iam_role.mdmCredentialAccessRole.name
  policy_arn = aws_iam_policy.mdmCredentialAccess.arn
}

resource "aws_iam_instance_profile" "mdmCredentialInstanceProfile" {
  name = "mdmCredentialInstanceProfile"
  role = aws_iam_role.mdmCredentialAccessRole.name
}

output "mdmCredentialsID" {
  value = aws_ssm_parameter.mdmCredentialsTF.id
}
