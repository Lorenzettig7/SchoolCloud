# Default provider will be set by caller; we add an alias for the edge endpoint.
provider "aws" {
  alias  = "edge"
  region = "us-east-1"
}
