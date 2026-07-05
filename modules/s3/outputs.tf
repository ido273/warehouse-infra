output "bucket_name" {
  value = aws_s3_bucket.warehouse_images.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.warehouse_images.arn
}