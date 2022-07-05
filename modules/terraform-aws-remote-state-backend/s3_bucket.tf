#-------------------------------------------------------------------------------------------------------
# terraform options and locals
#-------------------------------------------------------------------------------------------------------

terraform {
  experiments = [module_variable_optional_attrs]
}

locals {}

#-------------------------------------------------------------------------------------------------------
# aws resrouces for backend configuration, with possible replication. 
#-------------------------------------------------------------------------------------------------------
#--------------------------------------
# primary s3 bucket, key, role/policy
#--------------------------------------
#-------------
# data points
#-------------

data "aws_region" "main" {
  provider = aws
}

data "aws_iam_policy_document" "bucket_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.backend_bucket.arn,
      "${aws_s3_bucket.backend_bucket.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

#-------------
# kms key
#-------------

resource "aws_kms_key" "bucket_key" {
  description             = "Used for encryption of ${format("tf-remote-state-%s-backend", var.project)}"
  enable_key_rotation     = true
  tags      = merge(
    { 
    "Name" = format("tf-remote-state-%s-backend-key", var.project)
    },
    var.tags, 
  )
}

resource "aws_kms_alias" "bucket_key_alias" {
  name          = "alias/${format("tf-remote-state-%s-backend-key", var.project)}"
  target_key_id = aws_kms_key.bucket_key.arn
}

#-------------
# s3 bucket
#-------------

resource "aws_s3_bucket" "backend_bucket" {
  bucket              = format("tf-remote-state-%s-backend", var.project)
  force_destroy       = var.force_destroy
  tags                = merge(
    { 
    "Name" = format("tf-remote-state-%s-backend", var.project)
    },
    var.tags, 
  )
}

resource "aws_s3_bucket_acl" "backend_bucket_acl" {
  bucket = aws_s3_bucket.backend_bucket.id
  acl    = "private" 
}

resource "aws_s3_bucket_versioning" "backend_bucket_versioning" {
  bucket = aws_s3_bucket.backend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "server_side_encryption" {
  bucket = aws_s3_bucket.backend_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_alias.bucket_key_alias.id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket                  = aws_s3_bucket.backend_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "bucket_force_ssl" {
  bucket     = aws_s3_bucket.backend_bucket.id
  policy     = data.aws_iam_policy_document.bucket_force_ssl.json
  depends_on = [aws_s3_bucket_public_access_block.block_public_access]
}


resource "aws_s3_bucket_replication_configuration" "replication_config" {
  bucket   = aws_s3_bucket.backend_bucket.id
  role     = aws_iam_role.replication_role.arn
  rule {
    id     = "replica_configuration"
    status = "Enabled"
    
    filter {}
    
    delete_marker_replication {
      status = "Disabled"
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.replica_bucket.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica_key.arn
      }
    }
  }
}