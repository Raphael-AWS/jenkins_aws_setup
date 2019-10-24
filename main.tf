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
## Master jenkins instance
resource "aws_instance" "jenkins_master" {
  ami               = "${lookup(var.amis,var.aws_region)}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${var.security_group_id}"]
  subnet_id              = "${var.subnet_id}"
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = false
  }

}


// Jenkins slaves launch configuration
resource "aws_launch_configuration" "jenkins_slave_launch_conf" {
  name            = "jenkins_slaves_config"
  image_id        = "${lookup(var.amis,var.aws_region)}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${var.security_group_id}"]
  #user_data       = "${data.template_file.user_data_slave.rendered}"
   user_data       = "${file("userdata.sh")}"
root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = false
  }
  lifecycle {
    create_before_destroy = true
  }
}
// ASG Jenkins slaves
resource "aws_autoscaling_group" "jenkins_slaves" {
  name                 = "jenkins_slaves_asg"
  launch_configuration = "${aws_launch_configuration.jenkins_slave_launch_conf.name}"
  vpc_zone_identifier  = ["${var.subnet_id}"]
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  depends_on = ["aws_instance.jenkins_master"]
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "jenkins_slave"
    propagate_at_launch = true
  }
  tag {
    key                 = "Author"
    value               = "coe-wipro"
    propagate_at_launch = true
  }
  tag {
    key                 = "Tool"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

// Scale out
resource "aws_cloudwatch_metric_alarm" "high-cpu-jenkins-slaves-alarm" {
  alarm_name          = "high-cpu-jenkins-slaves-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale-out.arn}"]
}
resource "aws_autoscaling_policy" "scale-out" {
  name                   = "scale-out-jenkins-slaves"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.jenkins_slaves.name}"
}
// Scale In
resource "aws_cloudwatch_metric_alarm" "low-cpu-jenkins-slaves-alarm" {
  alarm_name          = "low-cpu-jenkins-slaves-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale-in.arn}"]
}
resource "aws_autoscaling_policy" "scale-in" {
  name                   = "scale-in-jenkins-slaves"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.jenkins_slaves.name}"
}
resource "aws_elb" "jenkins" {
  name = "jenkins-elb"
  security_groups = ["${var.security_group_id}"]
  #availability_zones   = ["${split(",", var.aws_availability_zones)}"]
#availability_zones = ["us-east-1a"]
#vpc_zone_identifier = ["${aws_subnet.public_subnet_us-east-1a.id}"]
subnets = ["${var.subnet_id}"]
health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }
}
