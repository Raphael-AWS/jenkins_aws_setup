variable "aws_region" {
  description = "AWS region for hosting our your network"
  default = "us-east-1"
}
variable "amis" {
    description = "AMIs by region"
    default = {
        us-east-1 = "ami-0cfee17793b08a293" # ubuntu 14.04 LTS
    }
}
variable "aws_key_name" {
  description = "Key name for SSHing into EC2"
  default = "blockchain"
}
variable "aws_availability_zones" {
  default     = "us-east-1a,us-east-1b,us-east-1c,us-east-1d"
  description = "List of availability zones, use AWS CLI to find your "
}
