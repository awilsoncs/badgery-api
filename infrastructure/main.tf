# Networking
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

# EC2
resource "aws_launch_template" "badgery_api" {
  name_prefix   = "badgery-api"
  image_id      = "ami-04e5276ebb8451442" #al2023
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "badgery_api" {
  vpc_zone_identifier = [aws_vpc.main.id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 0

  launch_template {
    id      = aws_launch_template.badgery_api.id
    version = "$Latest"
  }
}

# ECS
resource "aws_kms_key" "cluster_key" {
  description             = "badgery-api-cluster-key"
  deletion_window_in_days = 7
}

resource "aws_ecs_capacity_provider" "badgery_api" {
  name = "badgery-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.badgery_api.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 1
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "badgery_api" {
  cluster_name = aws_ecs_cluster.badgery_api.name

  capacity_providers = [aws_ecs_capacity_provider.badgery_api.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.badgery_api.name
  }
}

resource "aws_ecs_cluster" "badgery_api" {
  name = "badgery-api"
}

# TODO task definition
# TODO IAM role
# TODO IAM role policy
# TODO lb

# resource "aws_ecs_service" "mongo" {
#   name            = "mongodb"
#   cluster         = aws_ecs_cluster.badgery_api.id
#   task_definition = aws_ecs_task_definition.mongo.arn
#   desired_count   = 1
#   iam_role        = aws_iam_role.foo.arn
#   depends_on      = [aws_iam_role_policy.foo]

#   load_balancer {
#     target_group_arn = aws_lb_target_group.foo.arn
#     container_name   = "mongo"
#     container_port   = 8080
#   }

#   placement_constraints {
#     type       = "memberOf"
      # TODO remove this??
#     expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
#   }
# }

# ECR
resource "aws_ecr_repository" "badgery_api" {
  name                 = "badgery-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}