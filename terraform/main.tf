##############################
# Package Lambda code
##############################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/build/lambda.zip"
}

##############################
# IAM role for Lambda
##############################

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################
# Lambda function
##############################

resource "aws_lambda_function" "api" {
  function_name    = var.project_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 5
  memory_size      = 128
}

##############################
# ACM certificate for the API (same region as the API Gateway REGIONAL
# endpoint). DNS is managed at your registrar, not Route 53, so create the
# validation record manually - see the api_cert_validation_record output.
##############################

resource "aws_acm_certificate" "api" {
  domain_name       = var.api_subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.api.domain_validation_options : dvo.resource_record_name]
}

##############################
# API Gateway (HTTP API) -> Lambda
##############################

resource "aws_apigatewayv2_api" "api" {
  name          = var.project_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_me" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /me"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_resume" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /resume"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_projects" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /projects"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

##############################
# API Gateway custom domain (regional - no CloudFront involved).
# Point api_subdomain at the target in the api_gateway_target_domain output.
##############################

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = var.api_subdomain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.default.id
}

##############################
# Website: private S3 bucket read only via CloudFront (Origin Access
# Control), no public bucket access at all.
##############################

resource "aws_s3_bucket" "website" {
  bucket = var.website_subdomain
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project_name}-website-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "AllowCloudFrontServicePrincipal"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

##############################
# ACM certificate for the website. CloudFront only reads certs from
# us-east-1 - see the aws.us_east_1 provider alias in provider.tf. DNS is
# managed at your registrar, so create the validation record manually - see
# the website_cert_validation_record output.
##############################

resource "aws_acm_certificate" "website" {
  provider          = aws.us_east_1
  domain_name       = var.website_subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "website" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.website.domain_validation_options : dvo.resource_record_name]
}

##############################
# CloudFront distribution -> website_subdomain.
# Point website_subdomain at the target in the website_cloudfront_domain
# output.
##############################

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.website_subdomain]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "website-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "website-s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.website.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
