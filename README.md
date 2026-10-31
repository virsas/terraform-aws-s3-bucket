# Terraform AWS S3 Bucket Module

A Terraform module for managing [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) buckets together with the full set of companion configuration resources: bucket policy, public access block, versioning, server side encryption, lifecycle rules, logging, ownership controls, replication, CORS, event notifications, object lock and static website hosting.

## Features

- **Bucket Management**: Creates a single S3 bucket with a configurable name and optional object lock support.
- **Mandatory Bucket Policy**: Always attaches a bucket policy rendered from `<policy_path>/<name>.json` with `arn`, `account` and `region` template variables available.
- **Public Access Block**: Blocks public ACLs and public bucket policies by default, with each of the four settings individually configurable.
- **Versioning**: Enables object versioning by default and creates the versioning resource only while versioning is turned on.
- **Server Side Encryption**: Encrypts objects at rest with `AES256` by default, or with `aws:kms` and an optional customer managed KMS key.
- **Lifecycle Rules**: Accepts an arbitrary list of lifecycle rules supporting expiration, transition, filter and abort incomplete multipart upload blocks.
- **Object Lock**: Optionally creates the bucket with object lock enabled and applies a default retention mode and period to new objects.
- **Access Logging**: Optionally ships server access logs to a target bucket under a configurable prefix.
- **Object Ownership**: Optionally manages S3 bucket ownership controls. Disabled by default. Allowed settings are `BucketOwnerEnforced`, `BucketOwnerPreferred` and `ObjectWriter`.
- **Static Website Hosting**: Optionally serves the bucket as a static website with configurable index and error documents.
- **Event Notifications**: Optionally notifies an SQS queue or a Lambda function about bucket events.
- **CORS**: Optionally applies a CORS rule with configurable methods, origins, headers and exposed headers.
- **Cross Account Replication**: Optionally replicates objects to a bucket in another account, with optional KMS encrypted replicas and a configurable rule priority.

---

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

---

## Usage Examples

All examples assume a policy document exists at `<policy_path>/<name>.json`. The module always creates an `aws_s3_bucket_policy`, so this file is required. It is rendered with `templatefile()` and receives the `arn`, `account` and `region` variables:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["${arn}", "${arn}/*"],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
```

### Basic Example

Create a private, versioned, AES256 encrypted bucket with the default public access block:

```hcl
module "s3_bucket" {
  source = "git::https://github.com/virsas/terraform-aws-s3-bucket.git?ref=v1.1"

  name      = "vss-application-data"
  accountID = "123456789012"
  region    = "eu-west-1"
}
```

### Advanced Example (KMS Encryption, Logging & Lifecycle Rules)

Encrypt the bucket with a customer managed KMS key, ship access logs to a dedicated logging bucket and expire and transition objects on a schedule:

```hcl
module "s3_bucket_archive" {
  source = "git::https://github.com/virsas/terraform-aws-s3-bucket.git?ref=v1.1"

  name      = "vss-application-archive"
  accountID = "123456789012"
  region    = "eu-west-1"

  policy_path = "./json/s3"

  encryption_enabled   = true
  encryption_algorithm = "aws:kms"
  encryption_kms_key   = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  versioning_enabled = true

  logging_bucket = "vss-access-logs"
  logging_prefix = "s3"

  lifecycle_rules = [
    {
      name    = "ExpireTempAfterWeek"
      enabled = true
      filter = {
        prefix = "tmp/"
      }
      expiration = {
        days = 7
      }
    },
    {
      name                               = "ArchiveOldObjects"
      enabled                            = true
      abort_incomplete_multipart_in_days = 3
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]
}
```

### Static Website Example (Website Hosting & CORS)

Serve the bucket as a static website, relax the public access block so a public read policy can be attached and allow cross origin `GET` requests:

```hcl
module "s3_bucket_website" {
  source = "git::https://github.com/virsas/terraform-aws-s3-bucket.git?ref=v1.1"

  name      = "vss-application-website"
  accountID = "123456789012"
  region    = "eu-west-1"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  website_enabled    = true
  website_index_page = "index.html"
  website_error_page = "404.html"

  cors_rules = {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://example.com"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
  }
}
```

### Compliance Example (Object Lock, Notifications & Cross Account Replication)

Create a write once read many bucket that locks every new object for a year, notifies an SQS queue on object creation and replicates objects into a bucket owned by another account using KMS encrypted replicas:

```hcl
module "s3_bucket_compliance" {
  source = "git::https://github.com/virsas/terraform-aws-s3-bucket.git?ref=v1.1"

  name      = "vss-application-compliance"
  accountID = "123456789012"
  region    = "eu-west-1"

  object_lock_enabled = true
  object_lock_config = {
    mode = "COMPLIANCE"
    days = 365
  }

  notification_sqs = {
    queue_arn     = "arn:aws:sqs:eu-west-1:123456789012:vss-s3-events"
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }

  replication_enabled     = true
  replication_role        = "arn:aws:iam::123456789012:role/vss-s3-replication"
  replication_dst_arn     = "arn:aws:s3:::vss-application-compliance-replica"
  replication_dst_account = "210987654321"
  replication_priority    = 1

  replication_kms_enabled = true
  replication_kms_arn     = "arn:aws:kms:eu-central-1:210987654321:key/87654321-4321-4321-4321-210987654321"
}
```

---

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_notification.vss_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_notification.vss_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_object_lock_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_website_configuration.vss](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration) | resource |

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the bucket. Must be globally unique and is also used as the file name of the bucket policy and as the logging prefix. | `string` | n/a | yes |
| <a name="input_accountID"></a> [accountID](#input\_accountID) | AWS account ID, passed to the bucket policy template as the `account` variable. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region, passed to the bucket policy template as the `region` variable. | `string` | n/a | yes |
| <a name="input_object_lock_enabled"></a> [object\_lock\_enabled](#input\_object\_lock\_enabled) | Create the bucket with object lock enabled or disabled. This value cannot be changed after the bucket is created, and object locks are not applied by default. | `bool` | `false` | no |
| <a name="input_object_lock_config"></a> [object\_lock\_config](#input\_object\_lock\_config) | Default object lock retention applied to all newly created objects, for example `{ mode = "COMPLIANCE", days = 365 }`. Allowed modes are `GOVERNANCE` and `COMPLIANCE`, and `mode` defaults to `COMPLIANCE` when omitted. Only applied when `object_lock_enabled` is `true`. | `map` | `{}` | no |
| <a name="input_block_public_acls"></a> [block\_public\_acls](#input\_block\_public\_acls) | Reject `PUT Bucket ACL`, `PUT Object ACL` and `PUT Object` calls whose request includes a public ACL. | `bool` | `true` | no |
| <a name="input_block_public_policy"></a> [block\_public\_policy](#input\_block\_public\_policy) | Reject `PUT Bucket policy` calls if the specified bucket policy allows public access. | `bool` | `true` | no |
| <a name="input_ignore_public_acls"></a> [ignore\_public\_acls](#input\_ignore\_public\_acls) | Ignore all public ACLs on this bucket and any objects it contains. | `bool` | `true` | no |
| <a name="input_restrict_public_buckets"></a> [restrict\_public\_buckets](#input\_restrict\_public\_buckets) | Allow only the bucket owner and AWS services to access the bucket when it has a public policy. | `bool` | `true` | no |
| <a name="input_policy_path"></a> [policy\_path](#input\_policy\_path) | Directory containing the bucket policy documents. The module always renders `<policy_path>/<name>.json`, so this file must exist. | `string` | `"./json/s3"` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Enable object versioning on the bucket. Disabling it does not delete existing versions, it only stops the versioning resource from being managed. | `bool` | `true` | no |
| <a name="input_logging_bucket"></a> [logging\_bucket](#input\_logging\_bucket) | Name of the bucket that receives server access logs. Leave as an empty string to disable logging. | `string` | `""` | no |
| <a name="input_logging_prefix"></a> [logging\_prefix](#input\_logging\_prefix) | Prefix under which access logs are stored, producing the path `s3://<logging_bucket>/<logging_prefix>/<name>/`. | `string` | `"s3"` | no |
| <a name="input_ownership_controls_enabled"></a> [ownership\_controls\_enabled](#input\_ownership\_controls\_enabled) | Manage S3 bucket ownership controls. When `false`, the ownership controls resource is not created. | `bool` | `false` | no |
| <a name="input_object_ownership"></a> [object\_ownership](#input\_object\_ownership) | Object ownership setting applied when `ownership_controls_enabled` is `true`. Allowed values are `BucketOwnerEnforced`, `BucketOwnerPreferred` and `ObjectWriter`. | `string` | `"BucketOwnerEnforced"` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | List of lifecycle rules. Each rule supports `name`, `enabled`, `abort_incomplete_multipart_in_days`, `filter` (`prefix`, `tags`, `object_size_greater_than`, `object_size_less_than`), `expiration` (`date`, `days`) and `transition` (`date`, `days`, `storage_class`). A JSON encoded string is also accepted and decoded automatically. | `any` | `[]` | no |
| <a name="input_website_enabled"></a> [website\_enabled](#input\_website\_enabled) | Enable static website hosting on the bucket. The website configuration is only created when both `website_index_page` and `website_error_page` are non empty. | `string` | `false` | no |
| <a name="input_website_index_page"></a> [website\_index\_page](#input\_website\_index\_page) | Suffix of the index document served for directory requests. | `string` | `"index.html"` | no |
| <a name="input_website_error_page"></a> [website\_error\_page](#input\_website\_error\_page) | Key of the error document returned for `4XX` responses. | `string` | `"404.html"` | no |
| <a name="input_encryption_enabled"></a> [encryption\_enabled](#input\_encryption\_enabled) | Enable server side encryption on the bucket. | `bool` | `true` | no |
| <a name="input_encryption_algorithm"></a> [encryption\_algorithm](#input\_encryption\_algorithm) | Server side encryption algorithm. Allowed values are `AES256`, `aws:kms` and `aws:kms:dsse`. | `string` | `"AES256"` | no |
| <a name="input_encryption_kms_key"></a> [encryption\_kms\_key](#input\_encryption\_kms\_key) | ARN or ID of the customer managed KMS key used when `encryption_algorithm` is `aws:kms`. Leave as `null` to fall back to the AWS managed `aws/s3` key. | `string` | `null` | no |
| <a name="input_cors_rules"></a> [cors\_rules](#input\_cors\_rules) | Single CORS rule applied to the bucket, for example `{ allowed_methods = ["GET"], allowed_origins = ["*"] }`. `allowed_methods` and `allowed_origins` are mandatory when set, while `allowed_headers` and `expose_headers` are optional. A JSON encoded string is also accepted and decoded automatically. Leave empty to skip the CORS configuration. | `any` | `{}` | no |
| <a name="input_notification_sqs"></a> [notification\_sqs](#input\_notification\_sqs) | SQS notification configuration, for example `{ queue_arn = "arn:aws:sqs:...", events = ["s3:ObjectCreated:*"], filter_suffix = "" }`. Leave empty to skip SQS notifications. | `any` | `{}` | no |
| <a name="input_notification_lambda"></a> [notification\_lambda](#input\_notification\_lambda) | Lambda notification configuration, for example `{ lambda_function_arn = "arn:aws:lambda:...", events = ["s3:ObjectCreated:*"], filter_suffix = "" }`. Leave empty to skip Lambda notifications. | `any` | `{}` | no |
| <a name="input_replication_enabled"></a> [replication\_enabled](#input\_replication\_enabled) | Enable cross account replication for the bucket. | `bool` | `false` | no |
| <a name="input_replication_role"></a> [replication\_role](#input\_replication\_role) | ARN of the IAM role S3 assumes to replicate objects. | `string` | `""` | no |
| <a name="input_replication_dst_arn"></a> [replication\_dst\_arn](#input\_replication\_dst\_arn) | ARN of the destination bucket. | `string` | `""` | no |
| <a name="input_replication_dst_account"></a> [replication\_dst\_account](#input\_replication\_dst\_account) | AWS account ID that owns the destination bucket. | `string` | `""` | no |
| <a name="input_replication_kms_enabled"></a> [replication\_kms\_enabled](#input\_replication\_kms\_enabled) | Replicate KMS encrypted source objects and encrypt the replicas with `replication_kms_arn`. | `bool` | `false` | no |
| <a name="input_replication_kms_arn"></a> [replication\_kms\_arn](#input\_replication\_kms\_arn) | ARN of the KMS key used to encrypt the replicas in the destination account. | `string` | `null` | no |
| <a name="input_replication_priority"></a> [replication\_priority](#input\_replication\_priority) | Priority of the replication rule, used to break ties when rule filters overlap. | `number` | `1` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | The name of the S3 bucket. |
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the S3 bucket. |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | The global domain name of the bucket, in the form `<name>.s3.amazonaws.com`. |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | The region specific domain name of the bucket. |
| <a name="output_region"></a> [region](#output\_region) | The region the bucket resides in. |
| <a name="output_s3_bucket_website_domain"></a> [s3\_bucket\_website\_domain](#output\_s3\_bucket\_website\_domain) | The website domain of the bucket, or an empty string when website hosting is disabled. |
| <a name="output_s3_bucket_website_endpoint"></a> [s3\_bucket\_website\_endpoint](#output\_s3\_bucket\_website\_endpoint) | The website endpoint of the bucket, or an empty string when website hosting is disabled. |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
