variable "aws_region" {
  description = "AWS region for hosting our your network"
  default = "us-east-1"
}
variable "amis" {
    description = "AMIs by region"
    default = {
        us-east-1 = "ami-04b9e92b5572fa0d1" # ubuntu 14.04 LTS
    }
}
variable "key_name" {
  description = "Key name for SSHing into EC2"
  default = "blockchain"
}
variable "aws_availability_zones" {
  default     = "eu-west-1a,us-east-1a,us-east-1b,us-east-1c,us-east-1d"
  description = "List of availability zones, use AWS CLI to find your "
}
variable "subnet_id" {
  description = "subnet id of vpc"
  default = "subnet-881a99a6"
}
variable "instance_type" {
  description = "subnet id of vpc"
  default = "t2.medium"
}
variable "security_group_id" {
  description = "subnet id of vpc"
  default = "sg-0e16de0c2453bce61"
}
variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "2"
}
variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "3"
}
variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "2"
}
