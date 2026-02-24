provider "aws" {
  region = var.aws_region
}

############################
# IAM ROLE FOR LAMBDA
############################

resource "aws_iam_role" "lambda_exec_role" {
  name = "snapshot-cleanup-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

############################
# IAM POLICY ATTACHMENTS
############################

# Allow Lambda to write logs
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda VPC access
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for EC2 snapshot access
resource "aws_iam_policy" "ec2_snapshot_policy" {
  name = "lambda-ec2-snapshot-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_snapshot_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.ec2_snapshot_policy.arn
}

############################
# SECURITY GROUP FOR LAMBDA
############################

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-snapshot-cleanup-sg"
  description = "Security group for Lambda in VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# ZIP THE LAMBDA CODE
############################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

############################
# LAMBDA FUNCTION
############################

resource "aws_lambda_function" "snapshot_cleanup" {
  function_name = "ec2-snapshot-cleanup"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 60
  memory_size = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RETENTION_DAYS = "365"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logging,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.attach_snapshot_policy
  ]
}

#####################EventBridge to execute the lambda bridge at 2:00AM UTC######################

resource "aws_cloudwatch_event_rule" "daily_snapshot_cleanup" {
  name                = "daily-ec2-snapshot-cleanup"
  description         = "Triggers Lambda daily to clean old EC2 snapshots"
  #schedule_expression = "rate(1 day)"
  schedule_expression = "cron(0 2 * * ? *)"
}
