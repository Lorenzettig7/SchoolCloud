data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "schoolcloud-tf-state-ycebq0"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
