data "aws_caller_identity" "current" {}

locals {
  operator_role_name       = "${var.project_name}-operator"
  operator_role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-operator"
  operator_login_user_name = "${var.project_name}-operator-login"
  project_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"
  project_profile_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-*"
}

resource "aws_iam_user" "operator_login" {
  name = local.operator_login_user_name

  tags = {
    Name = local.operator_login_user_name
  }
}

resource "aws_iam_user_policy" "assume_operator" {
  name = "assume-${local.operator_role_name}"
  user = aws_iam_user.operator_login.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeCloudDesignOperator"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = local.operator_role_arn
    }]
  })
}

resource "aws_iam_user_policy_attachment" "local_development_login" {
  user       = aws_iam_user.operator_login.name
  policy_arn = "arn:aws:iam::aws:policy/SignInLocalDevelopmentAccess"
}

resource "aws_iam_role" "operator" {
  name                 = local.operator_role_name
  description          = "Temporary operator access for the Cloud Design Terraform and audit workflow."
  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowAccountIdentityToAssume"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_user.operator_login.arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = local.operator_role_name
  }
}

resource "aws_iam_role_policy" "operator" {
  name = "${var.project_name}-operator"
  role = aws_iam_role.operator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageRegionalProjectServices"
        Effect = "Allow"
        Action = [
          "apigateway:*",
          "application-autoscaling:*",
          "autoscaling:*",
          "backup:*",
          "cloudwatch:*",
          "cognito-idp:*",
          "ec2:*",
          "ecr:*",
          "ecs:*",
          "elasticfilesystem:*",
          "elasticloadbalancing:*",
          "inspector2:*",
          "logs:*",
          "secretsmanager:*",
          "servicediscovery:*",
          "sns:*",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "ManageProjectStateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:ListBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration"
        ]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid    = "ManageProjectStateObjects"
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.state.arn}/*"
      },
      {
        Sid    = "ManageProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription"
        ]
        Resource = local.project_role_arn
      },
      {
        Sid    = "ManageProjectInstanceProfiles"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile"
        ]
        Resource = local.project_profile_arn
      },
      {
        Sid    = "ReadManagedPolicies"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions"
        ]
        Resource = "arn:aws:iam::aws:policy/*"
      },
      {
        Sid      = "CreateRequiredServiceLinkedRoles"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = [
              "autoscaling.amazonaws.com",
              "ecs.amazonaws.com",
              "ecs.application-autoscaling.amazonaws.com",
              "elasticloadbalancing.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}
