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
  name = "github-nico-pico-com"
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

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.domain}"
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.bucket
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
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "bucket_website_configuration" {
  bucket = aws_s3_bucket.s3_bucket.bucket

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "route53_zone" {
  name = var.domain
}

resource "aws_route53_record" "route53_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.route53_zone.zone_id
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_record : record.fqdn]
}

resource "aws_cloudfront_distribution" "cloudfront_s3_bucket_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
  }

  aliases = ["www.${var.domain}", var.domain]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.index_document

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.s3_bucket.bucket_regional_domain_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate.cert]
}

resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.route53_zone.zone_id

  name = var.domain
  type = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cloudfront_s3_bucket_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_s3_bucket_distribution.hosted_zone_id
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.route53_zone.zone_id

  name = "www.${var.domain}"
  type = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cloudfront_s3_bucket_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_s3_bucket_distribution.hosted_zone_id
  }
}