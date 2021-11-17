#////////////////////////////////////////////
# CREATE random suffix
resource "random_id" "random_id_suffix" {
  byte_length = 2
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key = "env:/common/vpc.tfstate"
    region = var.region
  }
}

data "template_file" "s3_bucket_template" {
  template = file("${path.module}/scripts/s3AccessPolicy.tftpl")
  vars = {
    bucketpath = aws_s3_bucket.img_mgr_bucket_v1.id
  }
}

#////////////////////////////////////////////
# CREATE s3 bucket to upload data from site
resource "aws_s3_bucket" "img_mgr_bucket_v1" {
  bucket   = "img-mgr-larryveloz-cat2021"
}

#////////////////////////////////////////////
# CREATE Security Group for LB
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow http from internet"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
  Environment = "${var.environment}"
  Name        = "larryveloz_lb_sg-${var.environment}"
 }
}

#////////////////////////////////////////////
# CREATE Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow http from internet"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
  Environment = "${var.environment}"
  Name        = "larryveloz_ec2_sg-${var.environment}"
 }
}

#////////////////////////////////////////////
# CREATE launch_template
resource "aws_launch_template" "img_mgr_template" {
  name                                 = "img-mgr-template-${var.environment}"
  image_id                             = "ami-02e136e904f3da870"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t2.micro"
  key_name                             = "ssm-automation"
  iam_instance_profile {
    name = aws_iam_instance_profile.img_mgr_profile.id
  }
  vpc_security_group_ids               = [aws_security_group.ec2_sg.id]
  user_data                            = base64encode(templatefile("${path.module}/user_data.sh", {S3Bucket = aws_s3_bucket.img_mgr_bucket_v1.id }))

  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name = "larryveloz_img-mgr-${var.environment}"
      Environment = "ENV-${var.environment}"
    }
  }
}



#////////////////////////////////////////////
# CREATE Auto Scaling Group
resource "aws_autoscaling_group" "img_mgr_asg" {
  vpc_zone_identifier = [data.terraform_remote_state.vpc.outputs.private_subnets_id[0]]
  desired_capacity    = 4
  max_size            = 6
  min_size            = 4

  launch_template {
    id      = aws_launch_template.img_mgr_template.id
    version = "$Latest"
  }
}

#////////////////////////////////////////////
# CREATE Application Load-Balancer
resource "aws_lb" "asg_lb" {
  name               = "ALB-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = [data.terraform_remote_state.vpc.outputs.public_subnets_id[0],data.terraform_remote_state.vpc.outputs.public_subnets_id[1]]

  tags = {
    Name        = "larryveloz_ALB_${var.environment}"
    Environment = "${var.environment}"
  }
}

resource "aws_lb_listener" "img_mgr_listener" {
  load_balancer_arn = aws_lb.asg_lb.arn
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.img-mgr-tg.arn
  }
}

resource "aws_lb_target_group" "img-mgr-tg" {
  name     = "img-mgr-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id
}

resource "aws_autoscaling_attachment" "img_mgr_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.id
  alb_target_group_arn   = aws_lb_target_group.img-mgr-tg.id
}

#////////////////////////////////////////////
# CREATE Bastion for access
# resource "aws_instance" "bastion" {
#   ami           = "ami-02e136e904f3da870"
#   instance_type = "t2.micro"
#   key_name      = "ssm-automation"
#   subnet_id     = data.terraform_remote_state.vpc.outputs.public_subnets_id[0]
#
#   tags = {
#     Name        = "larryveloz_bastion-${var.environment}"
#     Environment = "${var.environment}"
#   }
# }

#////////////////////////////////////////////
# ASG CPU High Scaling Policy
resource "aws_autoscaling_policy" "asg_cpu_high" {
  name                   = "ASG-CPUHigh-SP-${var.environment}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.name
}

#////////////////////////////////////////////
# CPU High Alarm for CPU High Scaling Policy
resource "aws_autoscaling_policy" "asg_cpu_low" {
  name                   = "CPULow-SP-${var.environment}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.img_mgr_asg.name
}

#////////////////////////////////////////////
# CPU High Alarm for CPU High Scaling Policy
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "CPUHigh-Alarm-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.CPUHighPolicy}"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.img_mgr_asg.name
  }

  alarm_description = "This metric monitors ec2 ASG high cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.asg_cpu_high.arn]
}

#////////////////////////////////////////////
# CPU Low Alarm for CPU Low Scaling Policy
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "CPULow-Alarm-${var.environment}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.CPULowPolicy}"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.img_mgr_asg.name
  }

  alarm_description = "This metric monitors ec2 ASG low cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.asg_cpu_high.arn]
}
