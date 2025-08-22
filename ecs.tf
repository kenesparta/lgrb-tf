resource "aws_ecs_cluster" "lgr_service_cluster" {
  name = "lgr-service-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_ssm_access" {
  name        = "ecs-task-ssm-access"
  description = "Allows ECS tasks to retrieve parameters from AWS Systems Manager Parameter Store"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ],
        Resource = [
          aws_ssm_parameter.jwt_secret.arn,
          aws_ssm_parameter.captcha_site_key.arn,
          aws_ssm_parameter.captcha_secret_key.arn,
          aws_ssm_parameter.database_url_rds.arn,
          aws_ssm_parameter.postgres_pasword.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_ssm_access.arn
}

resource "aws_iam_policy" "ecs_s3_access_policy" {
  name        = "ecs-task-s3-access-policy"
  description = "Allows ECS tasks to access private S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.private_app_bucket.arn,
          "${aws_s3_bucket.private_app_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_s3_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_s3_access_policy.arn
}
