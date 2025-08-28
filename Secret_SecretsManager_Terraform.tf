variable "MDMDomainNameOrIP" {
  description = "MDM domain name or IP address"
  type        = string
  sensitive   = false
}

variable "MDMEnrollmentUser" {
  description = "MDM username with privileges to create computer invitations."
  type        = string
  sensitive   = false
}

variable "MDMEnrollmentUserPassword" {
  description = "Password for MDM user with privileges to create computer invitations."
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

resource "aws_secretsmanager_secret" "mdmSecretTF" {
  name = "mdmSecret-Terraform-1"
#   If using the non-default key for the region, uncomment below and replace with your key ID.
#   kms_key_id = "replace_with_kms_key_id"
}

resource "aws_secretsmanager_secret_version" "mdmSecretTFPayload" {
  secret_id     = aws_secretsmanager_secret.mdmSecretTF.id
  secret_string = <<EOF
{"mdmServerDomain":"${var.MDMDomainNameOrIP}","mdmEnrollmentUser":"${var.MDMEnrollmentUser}","mdmEnrollmentPassword":"${var.MDMEnrollmentUserPassword}","localAdmin":"${var.LocalAdmin}","localAdminPassword":"${var.LocalAdminPassword}"}
EOF
}


data "aws_iam_policy_document" "mdmSecretAccessPolicyDoc" {
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
      aws_secretsmanager_secret.mdmSecretTF.id,
    ]
  }
}

resource "aws_iam_role" "mdmSecretAccessRole" {
  name               = "mdmSecretAccessRole"
  assume_role_policy = data.aws_iam_policy_document.mdmSecretAssumeRole.json
}

data "aws_iam_policy_document" "mdmSecretAssumeRole" {
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

resource "aws_iam_policy" "mdmSecretAccess" {
  name   = "mdmSecretAccess"
  policy = data.aws_iam_policy_document.mdmSecretAccessPolicyDoc.json
}

resource "aws_iam_role_policy_attachment" "mdmSecretAccessAttach" {
  role       = aws_iam_role.mdmSecretAccessRole.name
  policy_arn = aws_iam_policy.mdmSecretAccess.arn
}

resource "aws_iam_instance_profile" "mdmSecretInstanceProfile" {
  name = "mdmSecretInstanceProfile"
  role = aws_iam_role.mdmSecretAccessRole.name
}

output "mdmSecretARN" {
  value = aws_secretsmanager_secret.mdmSecretTF.arn
}
