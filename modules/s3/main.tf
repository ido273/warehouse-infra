resource "aws_s3_bucket" "warehouse_images" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "warehouse_images" {
  bucket = aws_s3_bucket.warehouse_images.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "warehouse_images" {
  bucket = aws_s3_bucket.warehouse_images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.warehouse_images.arn}/*"
    }]
  })
}
