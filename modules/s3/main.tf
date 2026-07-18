data "aws_caller_identity" "current" {}

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
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_images.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_key" "s3_images" {
  description             = "KMS key for S3 images bucket encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Backend IRSA"
        Effect = "Allow"
        Principal = {
          AWS = module.backend_s3_irsa.iam_role_arn
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "s3_images" {
  name          = "alias/warehouse-s3-images-${var.environment}"
  target_key_id = aws_kms_key.s3_images.key_id
}