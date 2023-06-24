resource "aws_ecs_cluster" "test" {
  lifecycle {
    create_before_destroy = true
  }

  name = "testCluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Env  = "test"
    Name = "test"
  }
}

# Create a task definition
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                = "ecs-task"
  container_definitions = <<EOF
[
  {
    "name": "my-container",
    "image": "nginx",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ]
  }
]
EOF

  task_role_arn       = aws_iam_role.ecs_task_role.arn
  execution_role_arn  = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
}

resource "aws_ecs_service" "default" {
  cluster                 = aws_ecs_cluster.test.id
  desired_count           = 1
  enable_ecs_managed_tags = true
  force_new_deployment    = true

  load_balancer {
    target_group_arn = aws_alb_target_group.default.arn
    container_name   = "app"
    container_port   = 80
  }

  network_configuration {
    subnets         = ["subnet-836b2f8d", "subnet-fef97b98"] 
    security_groups = [aws_security_group.ecs_security_group.id]
  }

  name            = "testwebapp"
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
}

# Create a security group
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  vpc_id      = "vpc-12345678"
  description = "ECS Security Group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a load balancer
resource "aws_lb" "ecs_load_balancer" {
  name               = "ecs-load-balancer"
  load_balancer_type = "application"
  subnets            = ["subnet-12345678", "subnet-87654321"]  # Replace with your desired subnet ID(s)

  security_groups = [aws_security_group.ecs_security_group.id]
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-12345678"  

  health_check {
    path = "/"
    port = 80
  }
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create an IAM role for ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
