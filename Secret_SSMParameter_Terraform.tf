variable "JamfDomainNameOrIP" {
  description = "Jamf domain name or IP address"
  type        = string
  sensitive   = false
}

variable "JamfEnrollmentUser" {
  description = "Jamf username with privileges to create computer invitations."
  type        = string
  sensitive   = false
}

variable "JamfEnrollmentUserPassword" {
  description = "Password for Jamf user with privileges to create computer invitations."
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

resource "aws_ssm_parameter" "jamfCredentialsTF" {
  name = "jamfCredentialsTF"
  type        = "String"
#   If using the non-default key for the region, uncomment below and replace with your key ID.
#   key_id = "replace_with_kms_key_id"
  value = <<EOF
{"jamfServerDomain":"${var.JamfDomainNameOrIP}","jamfEnrollmentUser":"${var.JamfEnrollmentUser}","jamfEnrollmentPassword":"${var.JamfEnrollmentUserPassword}","localAdmin":"${var.LocalAdmin}","localAdminPassword":"${var.LocalAdminPassword}"}
EOF
}

data "aws_iam_policy_document" "jamfCredentialAccessPolicyDoc" {
  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:GetParameterHistory"
    ]
    resources = [
      aws_ssm_parameter.jamfCredentialsTF.arn
    ]
  }
}

resource "aws_iam_role" "jamfCredentialAccessRole" {
  name               = "jamfCredentialAccessRole"
  assume_role_policy = data.aws_iam_policy_document.jamfCredentialAssumeRole.json
}

data "aws_iam_policy_document" "jamfCredentialAssumeRole" {
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

resource "aws_iam_policy" "jamfCredentialAccess" {
  name   = "jamfCredentialAccess"
  policy = data.aws_iam_policy_document.jamfCredentialAccessPolicyDoc.json
}

resource "aws_iam_role_policy_attachment" "jamfCredentialAccessAttach" {
  role       = aws_iam_role.jamfCredentialAccessRole.name
  policy_arn = aws_iam_policy.jamfCredentialAccess.arn
}

resource "aws_iam_instance_profile" "jamfCredentialInstanceProfile" {
  name = "jamfCredentialInstanceProfile"
  role = aws_iam_role.jamfCredentialAccessRole.name
}

output "jamfCredentialsID" {
  value = aws_ssm_parameter.jamfCredentialsTF.id
}