resource "aws_iam_user" "github_iam_user" {
  name = "github-nico-pico-com"
}

resource "aws_iam_access_key" "github_iam_access_key" {
  user = aws_iam_user.github_iam_user.name
}

resource "aws_iam_user_policy" "github_publish_iam_user_policy" {
  name = "github-nico-pico-com-policy"
  user = aws_iam_user.github_iam_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*", "s3-object-lambda:*", "cloudfront:*"],
      "Resource": "*"
    }
  ]
}
EOF
}