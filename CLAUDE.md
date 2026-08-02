# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A minimal personal API + website: three GET endpoints (`/me`, `/resume`,
`/projects`, each backed by a static JSON file) and a static website
bucket, both served on a custom domain over HTTPS. Entirely Terraform + one
Python Lambda handler — no build step, no package manager, no test suite.

Request flow:

```
Browser --> API Gateway (HTTP API, regional custom domain, HTTPS) --> Lambda
Browser --> CloudFront (HTTPS) --> S3 (private, Origin Access Control)
```

The API is regional — API Gateway's own custom-domain feature serves it
directly, no CDN in front. The website is fronted by CloudFront reading
from a private S3 bucket (no public bucket access; CloudFront reaches it
via `aws_cloudfront_origin_access_control`).

## DNS lives at the registrar, not Route 53

There is no Route 53 hosted zone anywhere in this config — DNS for the
domain stays with the user's registrar (GoDaddy). This means ACM
certificates can't be auto-validated via a Terraform-managed Route 53
record, and the final CNAMEs can't be auto-created either. Both are handled
via **outputs the user copies into their registrar's DNS panel by hand**:

- `api_cert_validation_record` / `website_cert_validation_record` — the
  DNS-validation CNAME for each ACM cert (`aws_acm_certificate.api` /
  `aws_acm_certificate.website`). `aws_acm_certificate_validation` polls
  ACM's status directly, so it works fine once these are created manually.
- `api_gateway_target_domain` / `website_cloudfront_domain` — the final
  CNAME target for `api_subdomain` / `website_subdomain` once each cert is
  issued.

`terraform apply` will block on `aws_acm_certificate_validation` until the
matching DNS record exists and ACM sees it — this is expected, not a bug.

If a future change reintroduces Route 53 (e.g. delegating the whole domain
or just a subdomain to AWS), the manual-CNAME outputs above and the
`aws_acm_certificate_validation.*` resources' `validation_record_fqdns`
would need to be revisited.

## Repo layout

```
terraform/   main.tf, variables.tf, outputs.tf, provider.tf,
             terraform.tfvars(.example), .terraform.lock.hcl
lambda/      handler.py, me.json, resume.json, projects.json
```

`main.tf`'s `data.archive_file.lambda_zip` sources
`"${path.module}/../lambda"` as the zip's `source_dir` — that's why
`lambda/` is a sibling of `terraform/` rather than nested inside it. All
Terraform commands are run from inside `terraform/`.

`handler.py` is a single Lambda behind one API Gateway HTTP API
(`AWS_PROXY` integration, payload format 2.0). It routes on `event["rawPath"]`
via a `path -> filename` dict (`_ROUTES`), loading `me.json`/`resume.json`/
`projects.json` into memory once at module load and serving them read-only.
Adding another endpoint means: add a JSON file to `lambda/`, add its
path/filename to `_ROUTES` in `handler.py`, and add a matching
`aws_apigatewayv2_route` in `main.tf` pointing at the same
`aws_apigatewayv2_integration.lambda`.

## Commands

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set api_subdomain and website_subdomain
terraform init
terraform plan
terraform apply
# apply will pause on ACM validation — see "DNS lives at the registrar" above

# After deploy
terraform output api_endpoint
terraform output website_endpoint

# Tear down
terraform destroy
```

There is no lint/test/build tooling configured in this repo (no Makefile,
no CI config, no Python test files). `terraform fmt` / `terraform validate`
work normally.

## Updating the served data

Edit `lambda/me.json`, `lambda/resume.json`, or `lambda/projects.json` and
re-run `terraform apply` (from `terraform/`). Terraform recomputes the
Lambda zip's `source_code_hash` (via `data.archive_file.lambda_zip`) and
redeploys the function automatically — no separate packaging step.

`resume.json` follows the [JSON Resume](https://jsonresume.org/schema/)
schema (`basics`/`work`/`education`/`skills`/`projects`/etc.) so it stays
compatible with existing JSON Resume themes/tooling if needed later.
`projects.json` is a flat array of `{title, description, github_url}`
objects — unrelated to `resume.json`'s own (currently empty) `projects`
array, which is part of the JSON Resume spec.

## Updating the website

Upload files directly to the S3 bucket named after `website_subdomain`
(e.g. `www.example.com`) — Terraform doesn't manage website content, only
the bucket/CloudFront/cert infrastructure around it.

## Key resources in `main.tf`

- **Lambda**: `aws_lambda_function.api`, Python 3.12, handler
  `handler.handler`, packaged from `data.archive_file.lambda_zip`.
- **API ACM cert**: `aws_acm_certificate.api`, same AWS region as the API
  Gateway regional endpoint (default provider).
- **API Gateway**: HTTP API (`aws_apigatewayv2_api`) with `GET /me`,
  `GET /resume`, and `GET /projects` routes all proxying to the same Lambda
  integration, `$default` auto-deploy stage, and a regional custom domain
  (`aws_apigatewayv2_domain_name`) mapped to that stage via
  `aws_apigatewayv2_api_mapping`.
- **Website S3 bucket**: `aws_s3_bucket.website`, all public access blocked
  (`aws_s3_bucket_public_access_block`), readable only by CloudFront via
  `aws_cloudfront_origin_access_control` + a scoped `aws_s3_bucket_policy`
  (condition on the specific distribution's ARN).
- **Website ACM cert**: `aws_acm_certificate.website` — uses the
  `aws.us_east_1` provider alias (`provider.tf`) because CloudFront only
  reads certs from `us-east-1`, regardless of `var.aws_region`.
- **CloudFront**: `aws_cloudfront_distribution.website`, single S3 origin,
  `PriceClass_100`, redirects HTTP to HTTPS.

`outputs.tf` exposes: raw `api_gateway_invoke_url` (works immediately,
before DNS), final `api_endpoint`/`website_endpoint` (work once DNS is set
up), the `*_cert_validation_record` and `api_gateway_target_domain`/
`website_cloudfront_domain` values needed for the manual registrar DNS
steps described above.

## Variables (`variables.tf`)

`aws_region` (default `us-east-1`), `project_name` (default `personal-api`,
prefixes resource names), `api_subdomain` and `website_subdomain` (both
required, no defaults).
