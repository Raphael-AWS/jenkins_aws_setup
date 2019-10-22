# Terraform state will be stored in S3
terraform {
  backend "s3" {
    bucket = "terraform-jenkins-s3"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
#setup Provider
provider "aws" {
  region = "${var.aws_region}"
}
# lookup for the "default" VPC
data "aws_vpc" "default_vpc" {
  default = true
}

# subnet list in the "default" VPC
# The "default" VPC has all "public subnets"
data "aws_subnet_ids" "default_public" {
  vpc_id = "${data.aws_vpc.default_vpc.id}"
}
# Security Group:
resource "aws_security_group" "jenkins_server" {
  name        = "jenkins_server"
  description = "Jenkins Server: created by Terraform for [dev]"

  # legacy name of VPC ID
  vpc_id = "${data.aws_vpc.default_vpc.id}"

  tags {
    Name = "jenkins_server"
    env  = "dev"
  }
}

###############################################################################
# ALL INBOUND
###############################################################################

# ssh
resource "aws_security_group_rule" "jenkins_server_from_source_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["<Your Public IP>/32", "172.0.0.0/8"]
  description       = "ssh to jenkins_server"
}

# web
resource "aws_security_group_rule" "jenkins_server_from_source_ingress_webui" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "jenkins server web"
}

# JNLP
resource "aws_security_group_rule" "jenkins_server_from_source_ingress_jnlp" {
  type              = "ingress"
  from_port         = 33453
  to_port           = 33453
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["172.31.0.0/16"]
  description       = "jenkins server JNLP Connection"
}

###############################################################################
# ALL OUTBOUND
###############################################################################

resource "aws_security_group_rule" "jenkins_server_to_other_machines_ssh" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins servers to ssh to other machines"
}

resource "aws_security_group_rule" "jenkins_server_outbound_all_80" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins servers for outbound yum"
}

resource "aws_security_group_rule" "jenkins_server_outbound_all_443" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.jenkins_server.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins servers for outbound yum"
}
# lookup the security group of the Jenkins Server
data "aws_security_group" "jenkins_server" {
  filter {
    name   = "group-name"
    values = ["jenkins_server"]
  }
}

# userdata for the Jenkins server ...
data "template_file" "jenkins_server" {
  template = "${file("scripts/jenkins_server.sh")}"

  vars {
    env = "dev"
    jenkins_admin_password = "mysupersecretpassword"
  }
}

# the Jenkins server itself
resource "aws_instance" "jenkins_server" {
  ami                       = "${lookup(var.amis,var.aws_region)}"
  instance_type          		= "t3.medium"
  key_name                  = "${var.aws_key_name}"
  subnet_id              		= "${data.aws_subnet_ids.default_public.ids[0]}"
  vpc_security_group_ids 		= ["${data.aws_security_group.jenkins_server.id}"]
  iam_instance_profile   		= "dev_jenkins_server"
  user_data                 = "${file("userdata.sh")}"

  tags {
    "Name" = "jenkins_server"
  }

  root_block_device {
    delete_on_termination = true
  }
}
output "jenkins_server_public_ip" {
  value = "${aws_instance.jenkins_server.public_ip}"
}

output "jenkins_server_private_ip" {
  value = "${aws_instance.jenkins_server.private_ip}"
}
