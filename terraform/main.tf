terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  localstack_port = 4566
  region          = "us-east-1"
  service         = "poc-localstack"
}

provider "aws" {
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  region                      = local.region
  s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    cloudwatch     = "http://localhost:${local.localstack_port}"
    dynamodb       = "http://localhost:${local.localstack_port}"
    firehose       = "http://localhost:${local.localstack_port}"
    iam            = "http://localhost:${local.localstack_port}"
    kinesis        = "http://localhost:${local.localstack_port}"
    lambda         = "http://localhost:${local.localstack_port}"
    s3             = "http://localhost:${local.localstack_port}"
    secretsmanager = "http://localhost:${local.localstack_port}"
    sns            = "http://localhost:${local.localstack_port}"
    sqs            = "http://localhost:${local.localstack_port}"
  }
}

resource "aws_s3_bucket" "raw_bucket" {
  bucket = "${local.service}-raw-bucket"
  acl    = "public-read-write"
}

# resource "aws_cloudwatch_log_group" "raw_firehose_cw_log_group" {
#   name = "${local.service}-raw-firehose-cw-lg"
# }

# resource "aws_cloudwatch_log_stream" "raw_firehose_cw_log_stream" {
#   name           = "${local.service}-raw-firehose-cw-ls"
#   log_group_name = aws_cloudwatch_log_group.raw_firehose_cw_log_group.name
# }

data "aws_iam_policy_document" "raw_firehose_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    sid     = "RawFirehoseAssumeRole"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "raw_firehose_role" {
  name               = "${local.service}-raw-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.raw_firehose_assume_role.json
}

data "aws_iam_policy_document" "raw_firehose_policies" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject*"
    ]

    resources = [
      aws_s3_bucket.raw_bucket.arn,
      "${aws_s3_bucket.raw_bucket.arn}/*"
    ]
  }

  # statement {
  #   actions = [
  #     "logs:PutLogEvents",
  #     "logs:PutLogEventsBatch",
  #     "cloudwatch:PutMetricData"
  #   ]

  #   resources = [
  #     aws_cloudwatch_log_group.raw_firehose_cw_log_group.arn,
  #     aws_cloudwatch_log_stream.raw_firehose_cw_log_stream.arn
  #   ]
  # }
}

resource "aws_iam_policy" "raw_firehose_policies" {
  name   = "${local.service}-raw-firehose-policies"
  policy = data.aws_iam_policy_document.raw_firehose_policies.json
}

resource "aws_iam_role_policy_attachment" "raw_firehose_policies_attachment" {
  role       = aws_iam_role.raw_firehose_role.name
  policy_arn = aws_iam_policy.raw_firehose_policies.arn
}

resource "aws_kinesis_firehose_delivery_stream" "raw_firehose" {
  name        = "${local.service}-raw-firehose"
  destination = "extended_s3"


  extended_s3_configuration {
    role_arn           = aws_iam_role.raw_firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw_bucket.arn
    buffer_interval    = 60
    buffer_size        = 5 # MiB
    compression_format = "GZIP"

    # cloudwatch_logging_options {
    #   enabled         = true
    #   log_group_name  = aws_cloudwatch_log_group.raw_firehose_cw_log_group.name
    #   log_stream_name = aws_cloudwatch_log_stream.raw_firehose_cw_log_stream.name
    # }
  }
}
