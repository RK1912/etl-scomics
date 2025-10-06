terraform {

  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "scomics-glue-tfstate"       # create this bucket once
    key            = "etl-scomics/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"          # create a DynamoDB table with 'LockID' as primary key
  }
}


provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "etl-scomics"
}

variable "environment" {
  default = "dev"
}

# S3 Buckets
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.project_name}-scripts-${var.environment}"
  
  tags = {
    Name        = "Glue Scripts"
    Environment = var.environment
    Project     = "scomics-etl"
  }
}

resource "aws_s3_bucket" "output" {
  bucket = "${var.project_name}-output-${var.environment}"
  
  tags = {
    Name        = "Job Output"
    Environment = var.environment
    Project     = "scomics-etl"
  }
}

# IAM Role for Glue
resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "${var.project_name}-glue-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.scripts.arn}/*",
          "${aws_s3_bucket.output.arn}/*",
          aws_s3_bucket.scripts.arn,
          aws_s3_bucket.output.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Glue Job
resource "aws_glue_job" "hello_world_job" {
  name     = "${var.project_name}-hello-job-${var.environment}"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/hello_world.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--output_bucket"                    = "s3://${aws_s3_bucket.output.bucket}"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10

  tags = {
    Name        = "Hello World Job"
    Environment = var.environment
    Project     = "scomics-etl"
  }
}

# Outputs
output "scripts_bucket" {
  value = aws_s3_bucket.scripts.bucket
}

output "output_bucket" {
  value = aws_s3_bucket.output.bucket
}

output "glue_job_name" {
  value = aws_glue_job.hello_world_job.name
}