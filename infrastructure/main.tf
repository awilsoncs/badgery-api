# Networking
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "east_1a" {
  availability_zone = "us-east-1a"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "east_1b" {
  availability_zone = "us-east-1b"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_lb" "badgery_api" {
  name               = "badgery-api-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.allow_http.id ]
  subnets            = [ aws_subnet.east_1a.id, aws_subnet.east_1b.id ]

  depends_on = [ aws_subnet.east_1a, aws_subnet.east_1b ]
}

resource "aws_lb_target_group" "badgery_api" {
  name        = "badgery-api-lb-target-group"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
}

resource "aws_lb_listener" "badgery_api" {
  load_balancer_arn = aws_lb.badgery_api.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.badgery_api.arn
  }
}

# Security
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv6" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv6         = "::/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# IAM
resource "aws_iam_role" "badgery_api" {
  name = "badgery-api-aws-iam-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecs_task_execution_role" {
  name        = "ecs-task-execution-role-iam-policy"
  description = "Policy for BadgeryAPI ECS service"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = [
        "ec2:Describe*",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "sqs:SendMessage"
      ],
      Resource  = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.badgery_api.name
  policy_arn = aws_iam_policy.ecs_task_execution_role.arn
}

# EC2
resource "aws_launch_template" "badgery_api" {
  name_prefix   = "badgery-api-launch-template"
  image_id      = "ami-04e5276ebb8451442" #al2023
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "badgery_api" {
  vpc_zone_identifier = [ aws_subnet.east_1a.id, aws_subnet.east_1b.id ]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 0

  launch_template {
    id      = aws_launch_template.badgery_api.id
    version = "$Latest"
  }
}

# ECS
resource "aws_ecs_capacity_provider" "badgery_api" {
  name = "badgery-api-ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.badgery_api.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 1
    }
  }

}

resource "aws_ecs_cluster" "badgery_api" {
  name = "badgery-api-ecs-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "badgery_api" {
  cluster_name = aws_ecs_cluster.badgery_api.name

  capacity_providers = [aws_ecs_capacity_provider.badgery_api.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.badgery_api.name
  }
}

resource "aws_ecs_service" "badgery_api" {
  name            = "badgery-api-ecs-service"
  cluster         = aws_ecs_cluster.badgery_api.id
  task_definition = aws_ecs_task_definition.badgery_api.arn
  desired_count   = 1
  iam_role        = aws_iam_role.badgery_api.arn
  depends_on      = [ aws_iam_policy.ecs_task_execution_role ]

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.badgery_api.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.badgery_api.arn
    container_name   = "badgery_api_container"
    container_port   = 8080
  }

}

resource "aws_ecs_task_definition" "badgery_api" {
  family                   = "badgery-api-task-definition"
  container_definitions    = jsonencode([
    {
      name      = "badgery_api_container"
      image     = aws_ecr_repository.badgery_api.repository_url
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])

  network_mode = "host"

  execution_role_arn = aws_iam_role.badgery_api.arn
}

# ECR
resource "aws_ecr_repository" "badgery_api" {
  name                 = "badgery-api-aws-ecr-repository"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}