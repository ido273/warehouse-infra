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

  # Block ACL-based public access entirely. Public read is granted only through
  # the explicit, least-privilege bucket policy below (GetObject on objects),
  # so restrict_public_buckets stays false to let that policy take effect.
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
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

  depends_on = [aws_s3_bucket_public_access_block.warehouse_images]
}
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.warehouse_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}