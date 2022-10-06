variable "domain" {
  type = string
}

variable "index_document" {
  type = string
  default = "index.html"
}

variable "error_document" {
  type = string
  default = "404.html"
}

resource "aws_iam_user" "github_iam_user" {
  name = "github"
}

resource "aws_iam_access_key" "github_iam_access_key" {
  user = aws_iam_user.github_iam_user.name
}

resource "aws_iam_user_policy" "github_publish_iam_user_policy" {
  name = "github-publish-to-s3"
  user = aws_iam_user.github_iam_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*", "s3-object-lambda:*"],
      "Resource": "*"
    }
  ]
}
EOF
}

# Main www S3 bucket
resource "aws_s3_bucket" "www_s3_bucket" {
  bucket = "www.${var.domain}"
}

resource "aws_s3_bucket_policy" "www_s3_bucket_policy" {
  bucket = aws_s3_bucket.www_s3_bucket.bucket
  policy = data.aws_iam_policy_document.allow_get_object_access_globally.json
}

data "aws_iam_policy_document" "allow_get_object_access_globally" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.www_s3_bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "www_bucket_website_configuration" {
  bucket = aws_s3_bucket.www_s3_bucket.bucket

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# S3 bucket for redirecting non-www to www
resource "aws_s3_bucket" "non_www_s3_bucket" {
  bucket = var.domain
}

resource "aws_s3_bucket_acl" "non_www_s3_bucket_acl" {
  bucket = aws_s3_bucket.non_www_s3_bucket.bucket

  acl = "public-read"
}

resource "aws_s3_bucket_website_configuration" "non_www_s3_bucket_website_configuration" {
  bucket = aws_s3_bucket.non_www_s3_bucket.bucket

  redirect_all_requests_to {
    host_name = "https://${aws_s3_bucket.www_s3_bucket.bucket}"
  }
}