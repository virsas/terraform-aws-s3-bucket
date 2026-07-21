output "id" {
  value = aws_s3_bucket.vss.id
}
output "arn" {
  value = aws_s3_bucket.vss.arn
}
output "bucket_domain_name" {
  value = aws_s3_bucket.vss.bucket_domain_name
}
output "bucket_regional_domain_name" {
  value = aws_s3_bucket.vss.bucket_regional_domain_name
}
output "region" {
  value = aws_s3_bucket.vss.region
}
output "s3_bucket_website_domain" {
  value = try(aws_s3_bucket_website_configuration.vss[0].website_domain, "")
}
output "s3_bucket_website_endpoint" {
  value = try(aws_s3_bucket_website_configuration.vss[0].website_endpoint, "")
}