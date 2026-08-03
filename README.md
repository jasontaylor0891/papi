# Personal API + website

Three GET API endpoints — `/me` (profile info), `/resume` ([JSON
Resume](https://jsonresume.org/schema/) formatted), and `/projects` (a list
of project title/description/GitHub URL) — plus a static website.

## Architecture

```
Browser --> API Gateway (HTTP API, regional custom domain, HTTPS) --> Lambda
Browser --> CloudFront (HTTPS) --> S3 (private, origin access control)
```

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set api_subdomain and website_subdomain

terraform init
terraform plan
terraform apply
```

## After deploy

```bash
terraform output api_endpoint
curl https://api.example.com/me
curl https://api.example.com/resume
curl https://api.example.com/projects

terraform output website_endpoint
```

See "Updating the website and API" below to publish content to it.

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


## Updating the website

Upload files directly to the S3 bucket named after `website_subdomain`
(e.g. `www.jasontaylor.info`) — Terraform doesn't manage website content,
only the bucket/CloudFront/cert infrastructure around it:

```bash
aws s3 sync website/ s3://<website_subdomain>/ --delete
```

## Tearing down

```bash
cd terraform
terraform destroy
```
