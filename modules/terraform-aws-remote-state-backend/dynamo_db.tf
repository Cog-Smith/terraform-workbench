#-----------------------------------------------------------------------
# dynamodb table and key
#-----------------------------------------------------------------------
resource "aws_kms_key" "locking_table_key" {
  description             = "Used for encryption of dynamodb table ${format("%s", var.project)}"
  enable_key_rotation     = true
  tags      = merge(
    { 
    "Name" = format("tf-remote-state-%s-locking-table-key", var.project)
    },
    var.tags, 
  )
}

resource "aws_kms_alias" "locking_table_key_alias" {
  name          = "alias/${format("tf-remote-state-%s-locking-table-key", var.project)}"
  target_key_id = aws_kms_key.locking_table_key.arn
}

resource "aws_dynamodb_table" "locking-table" {
  name         = format("tf-remote-state-%s-locking-table", var.project)
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_alias.locking_table_key_alias.arn
  } 

  tags      = merge(
    { 
    "Name" = format("tf-remote-state-%s-locking-table", var.project)
    },
    var.tags, 
  )   
}