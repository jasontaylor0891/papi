variable "aws_region" {
  description = "AWS region to deploy the Lambda function and API Gateway in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix resource names"
  type        = string
  default     = "personal-api"
}

variable "api_subdomain" {
  description = "Full subdomain the API will be served on (e.g. api.example.com)"
  type        = string
}

variable "website_subdomain" {
  description = "Full subdomain the website will be served on (e.g. www.example.com)"
  type        = string
}
