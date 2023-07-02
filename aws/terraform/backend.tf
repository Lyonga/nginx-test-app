terraform {
  backend "s3" {
    bucket         = "charlyoinfotect.cm"
    key            = "path/to/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    #dynamodb_table = "your-lock-table"
  }
}
