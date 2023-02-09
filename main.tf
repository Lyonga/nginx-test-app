provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "bucket_name" {
  bucket = "bucket-name-test-101-lyonchar"
  tags = {
    Name        = "test-bucket"
    Environment = "Dev"
  }
}
