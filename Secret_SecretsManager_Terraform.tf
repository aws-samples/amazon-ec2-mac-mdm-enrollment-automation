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

resource "aws_secretsmanager_secret" "jamfSecretTF" {
  name = "jamfSecret-Terraform-1"
#   If using the non-default key for the region, uncomment below and replace with your key ID.
#   kms_key_id = "replace_with_kms_key_id"
}

resource "aws_secretsmanager_secret_version" "jamfSecretTFPayload" {
  secret_id     = aws_secretsmanager_secret.jamfSecretTF.id
  secret_string = <<EOF
{"jamfServerDomain":"${var.JamfDomainNameOrIP}","jamfEnrollmentUser":"${var.JamfEnrollmentUser}","jamfEnrollmentPassword":"${var.JamfEnrollmentUserPassword}","localAdmin":"${var.LocalAdmin}","localAdminPassword":"${var.LocalAdminPassword}"}
EOF
}


data "aws_iam_policy_document" "jamfSecretAccessPolicyDoc" {
  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:ListSecrets"
    ]
    resources = [
      aws_secretsmanager_secret.jamfSecretTF.id,
    ]
  }
}

resource "aws_iam_role" "jamfSecretAccessRole" {
  name               = "jamfSecretAccessRole"
  assume_role_policy = data.aws_iam_policy_document.jamfSecretAssumeRole.json
}

data "aws_iam_policy_document" "jamfSecretAssumeRole" {
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

resource "aws_iam_policy" "jamfSecretAccess" {
  name   = "jamfSecretAccess"
  policy = data.aws_iam_policy_document.jamfSecretAccessPolicyDoc.json
}

resource "aws_iam_role_policy_attachment" "jamfSecretAccessAttach" {
  role       = aws_iam_role.jamfSecretAccessRole.name
  policy_arn = aws_iam_policy.jamfSecretAccess.arn
}

resource "aws_iam_instance_profile" "jamfSecretInstanceProfile" {
  name = "jamfSecretInstanceProfile"
  role = aws_iam_role.jamfSecretAccessRole.name
}

output "jamfSecretARN" {
  value = aws_secretsmanager_secret.jamfSecretTF.arn
}
