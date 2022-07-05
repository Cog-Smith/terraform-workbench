#-----------------------------------------------------------------------
# replica s3_bucket, key, and polices
#-----------------------------------------------------------------------
#-------------
# data points
#-------------

data "aws_region" "replica" {
  provider = aws.replica
}

data "aws_iam_policy_document" "replica_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.replica_bucket.arn,
      "${aws_s3_bucket.replica_bucket.arn}/*"
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
resource "aws_kms_key" "replica_key" {
  provider                = aws.replica
  description             = "Used for encryption of ${format("tf-remote-state-%s-backend-replica", var.project)}"
  enable_key_rotation     = true
  tags      = merge(
    { 
    "Name" = format("tf-remote-state-%s-replica-key", var.project)
    },
    var.tags, 
  )
}

resource "aws_kms_alias" "replica_alias" {
  provider      = aws.replica
  name          = "alias/${format("tf-remote-state-%s-replica-key", var.project)}"
  target_key_id = aws_kms_key.replica_key.arn
}

#-----------------
# iam role/policy
#-----------------

resource "aws_iam_role" "replication_role" {
  name               = format("tf-remote-state-%s-replication-role", var.project)
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
  tags               = merge(
    { 
    "Name" = format("tf-remote-state-%s-replication-role", var.project)
    },
    var.tags, 
  )
}

resource "aws_iam_policy" "replication_policy" {
  name        = format("tf-remote-state-%s-replication-policy", var.project)
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.backend_bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.backend_bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.replica_bucket.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "${aws_kms_key.bucket_key.arn}",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${data.aws_region.main.name}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.backend_bucket.arn}/*"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "${aws_kms_key.replica_key.arn}",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${data.aws_region.replica.name}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.replica_bucket.arn}/*"
          ]
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "replication_attachment" {
  name       = format("tf-remote-state-%s-policy-attchment", var.project)
  roles      = [ aws_iam_role.replication_role.name ]
  policy_arn = aws_iam_policy.replication_policy.arn
}

#-------------
# s3 bucket
#-------------


resource "aws_s3_bucket" "replica_bucket" {
  provider            = aws.replica
  bucket              = format("tf-remote-state-%s-backend-replica", var.project)
  force_destroy       = var.force_destroy
  tags                = merge(
    { 
    "Name" = format("tf-remote-state-%s-backend-replica", var.project)
    },
    var.tags, 
  )
}

resource "aws_s3_bucket_acl" "replica_bucket_acl" {
  provider = aws.replica  
  bucket   = aws_s3_bucket.replica_bucket.id
  acl      = "private" 
}

resource "aws_s3_bucket_versioning" "replica_bucket_versioning" {
  provider = aws.replica  
  bucket   = aws_s3_bucket.replica_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_server_side_encryption" {
  provider = aws.replica    
  bucket   = aws_s3_bucket.replica_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_alias.replica_alias.id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "replica_public_access" {
  provider                = aws.replica
  bucket                  = aws_s3_bucket.replica_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "replica_force_ssl_policy" {
  provider   = aws.replica
  bucket     = aws_s3_bucket.replica_bucket.id
  policy     = data.aws_iam_policy_document.replica_force_ssl.json
  depends_on = [ aws_s3_bucket_public_access_block.replica_public_access ]
}