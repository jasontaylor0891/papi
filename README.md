# Personal API + website (AWS, DNS at your registrar)

Three GET API endpoints — `/me` (profile info), `/resume` ([JSON
Resume](https://jsonresume.org/schema/) formatted), and `/projects` (a list
of project title/description/GitHub URL) — plus a static website bucket,
all served on your own domain over HTTPS. DNS stays at your registrar (e.g.
GoDaddy); nothing here requires moving your domain to Route 53.

## Architecture

```
Browser --> API Gateway (HTTP API, regional custom domain, HTTPS) --> Lambda
Browser --> CloudFront (HTTPS) --> S3 (private, origin access control)
```

The API is regional — API Gateway's own custom-domain feature serves
`api_subdomain` directly, no CDN in front of it. The website is fronted by
CloudFront, reading from a private S3 bucket that has no public access at
all (CloudFront reaches it via Origin Access Control).

Because DNS isn't delegated to Route 53, each ACM certificate is DNS
validated by hand: `terraform apply` creates the certs and then waits, and
you create the validation CNAME at your registrar using the
`*_cert_validation_record` outputs. Once each cert is issued, point
`api_subdomain` / `website_subdomain` at the `api_gateway_target_domain` /
`website_cloudfront_domain` outputs with CNAME records.

At <1,000 API calls/month you'll stay entirely inside Lambda's permanent
free tier (1M requests, 400K GB-seconds/month) and well within API
Gateway's free tier for the first 12 months; after that it's about $1 per
million HTTP API requests, so effectively $0 at your volume. CloudFront and
S3 for a low-traffic personal site are similarly within or close to their
free tiers.

## Prerequisites

1. A domain already registered (DNS can stay with your registrar).
2. Terraform >= 1.5 installed locally.
3. AWS CLI configured with credentials that have permission to create IAM
   roles, Lambda, API Gateway, ACM certs, S3, and CloudFront.

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set api_subdomain and website_subdomain

terraform init
terraform plan
terraform apply
```

`terraform apply` will pause while it polls for each ACM certificate to
validate. In a second terminal (or browser tab), run:

```bash
terraform output api_cert_validation_record
terraform output website_cert_validation_record
```

and create the matching CNAME record for each at your registrar. Once both
certs show as issued, `apply` finishes creating the API Gateway domain
mapping and CloudFront distribution. Then run:

```bash
terraform output api_gateway_target_domain
terraform output website_cloudfront_domain
```

and create a CNAME for `api_subdomain` and `website_subdomain` pointing at
those targets, respectively.

## After deploy

```bash
terraform output api_endpoint
curl https://api.example.com/me
curl https://api.example.com/resume
curl https://api.example.com/projects

terraform output website_endpoint
```

See "Updating the website" below to publish content to it.

## Updating the data

1. Edit `lambda/me.json`, `lambda/resume.json`, or `lambda/projects.json`.
2. Re-apply:
   ```bash
   cd terraform
   terraform apply
   ```
3. Confirm the plan — it should show only `~ update in-place` on
   `aws_lambda_function.api` (the code hash changed because the zip
   contents changed), nothing else. Type `yes`.

No DNS or cert steps are needed for this — those only happen once, during
initial deploy. The new content is live within seconds of `apply`
finishing.

## Updating the website

Upload files directly to the S3 bucket named after `website_subdomain`
(e.g. `www.jasontaylor.info`) — Terraform doesn't manage website content,
only the bucket/CloudFront/cert infrastructure around it:

```bash
aws s3 cp <file> s3://<website_subdomain>/<file>
```

CloudFront caches responses, so changes may take a short while to show up
even after the S3 object is updated.

## Cost at <1,000 calls/month, low-traffic website

- Lambda: $0 (well within free tier)
- API Gateway (HTTP API): $0 (well within free tier; ~$0.001 even after)
- S3 + CloudFront: a few cents/month at most for a small, low-traffic site
- ACM certificates: free
- DNS: whatever your registrar already charges you — no Route 53 hosted
  zone required

## Tearing down

```bash
cd terraform
terraform destroy
```
