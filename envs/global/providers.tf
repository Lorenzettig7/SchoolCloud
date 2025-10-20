provider "aws" {
  region = "us-east-1" # OK for Route 53
}

# ACM for CloudFront must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
