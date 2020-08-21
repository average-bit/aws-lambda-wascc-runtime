//
// waSCC runtime for AWS Lambda example configuration.
//

terraform {
  required_version = ">= 0.12.19"
}

provider "aws" {
  version = ">= 3.3.0"
}

//
// Data sources for current AWS account ID, partition and region.
//

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

//
// Lambda resources.
//

data "aws_lambda_layer_version" "slim" {
  layer_name = "wascc-slim-al2"
}

resource "aws_lambda_function" "example" {
  filename         = "${path.module}/app.zip"
  source_code_hash = filebase64sha256("${path.module}/app.zip")
  function_name    = "waSCC-example-custom"
  role             = aws_iam_role.example.arn
  handler          = "doesnt.matter"
  runtime          = "provided.al2"
  memory_size      = 256
  timeout          = 90

  layers = [data.aws_lambda_layer_version.slim.arn]

  environment {
    variables = {
      RUST_BACKTRACE = "1"
      RUST_LOG       = "info,cranelift_wasm=warn,cranelift_codegen=info"
    }
  }

  tracing_config {
    mode = "Active"
  }
}

//
// IAM resources.
//

resource "aws_iam_role" "example" {
  name = "waSCC-example-custom-Lambda-role"

  assume_role_policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOT
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name = "waSCC-example-custom-Lambda-CloudWatchLogsPolicy"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.example.function_name}:*"
      ]
    }
  ]
}
EOT
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

resource "aws_iam_policy" "xray" {
  name = "waSCC-example-custom-Lambda-XRayPolicy"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOT
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.xray.arn
}

//
// Outputs.
//

output "FunctionName" {
  value = aws_lambda_function.example.function_name
}
