##############################
# API
##############################

output "api_gateway_invoke_url" {
  description = "Default API Gateway URL (works immediately, before DNS propagates)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_endpoint" {
  description = "Your final custom-domain API endpoint"
  value       = "https://${var.api_subdomain}"
}

output "api_cert_validation_record" {
  description = "DNS record to create at your registrar to validate the API's ACM certificate"
  value = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "api_gateway_target_domain" {
  description = "CNAME target for api_subdomain, once the cert above is validated"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
}

##############################
# Website
##############################

output "website_endpoint" {
  description = "Your final custom-domain website endpoint"
  value       = "https://${var.website_subdomain}"
}

output "website_cert_validation_record" {
  description = "DNS record to create at your registrar to validate the website's ACM certificate"
  value = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "website_cloudfront_domain" {
  description = "CNAME target for website_subdomain, once the cert above is validated"
  value       = aws_cloudfront_distribution.website.domain_name
}
