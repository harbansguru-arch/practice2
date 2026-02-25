Below is a clear, senior-level explanation of how I would package and deploy the Lambda function using:

✅ AWS CLI (manual packaging)

✅ Terraform (Infrastructure as Code — preferred for Platform roles)

✅ Serverless Framework (application-focused approach)

1️⃣ Packaging & Deploying Using AWS CLI (Manual Approach)
Step 1: Prepare the Function Code

Directory structure:

lambda-cleanup/
 ├── lambda_function.py


If no external dependencies (like our EC2 cleanup example), packaging is simple.

Step 2: Create Deployment Package
zip lambda.zip lambda_function.py


If there were dependencies:

pip install -r requirements.txt -t .
zip -r lambda.zip .

Step 3: Create IAM Role (One-Time Setup)
aws iam create-role \
  --role-name snapshot-cleanup-role \
  --assume-role-policy-document file://trust-policy.json


Attach policies:

aws iam attach-role-policy \
  --role-name snapshot-cleanup-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

Step 4: Deploy Lambda
aws lambda create-function \
  --function-name snapshot-cleanup \
  --runtime python3.11 \
  --role arn:aws:iam::<ACCOUNT_ID>:role/snapshot-cleanup-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda.zip \
  --timeout 60


To update later:

aws lambda update-function-code \
  --function-name snapshot-cleanup \
  --zip-file fileb://lambda.zip

When to Use AWS CLI?

Quick testing

Small environments

Proof-of-concept

Manual troubleshooting

For production → I would not rely on manual CLI deployment.

2️⃣ Deploying with Terraform (Preferred for Platform Engineering)

This is the correct approach in enterprise environments.

Step 1: Structure Code
platform-lambda/
 ├── main.tf
 ├── variables.tf
 ├── lambda_function.py
 ├── lambda.zip

Step 2: Package Automatically (Best Practice)

Add this to Terraform:

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda.zip"
}


Then reference:

resource "aws_lambda_function" "snapshot_cleanup" {
  function_name = "snapshot-cleanup"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 60
}

Step 3: Deploy
terraform init
terraform plan
terraform apply

Why Terraform is Preferred

Version controlled infrastructure

Repeatable deployments

Drift detection

State tracking

CI/CD integration

Environment promotion (dev/stage/prod)

In production, I would also:

Store remote state in S3

Use DynamoDB for state locking

Modularize Lambda into reusable modules

Integrate into GitLab CI pipeline

3️⃣ Using Serverless Framework

Best suited when developers own the Lambda lifecycle.

Install
npm install -g serverless

serverless.yml Example
service: snapshot-cleanup

provider:
  name: aws
  runtime: python3.11
  region: us-west-2
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - ec2:DescribeSnapshots
            - ec2:DeleteSnapshot
          Resource: "*"

functions:
  cleanup:
    handler: lambda_function.lambda_handler
    timeout: 60

Deploy
serverless deploy

When to Use Serverless Framework?

Developer-owned services

Rapid iteration
