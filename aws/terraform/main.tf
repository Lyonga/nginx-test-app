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
  family                   = "ecs-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "ecs-task",
      "image": "docker.io/lyonga/launch:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_ecs_service" "ecs-service" {
  cluster                 = aws_ecs_cluster.test.id
  desired_count           = 1
  enable_ecs_managed_tags = true
  force_new_deployment    = true

  load_balancer {
    target_group_arn = "${aws_lb_target_group.ecs_target_group.arn}"
    container_name   = "app"
    container_port   = 3000
  }

  network_configuration {
    subnets         = ["subnet-836b2f8d", "subnet-ec81d3a1"]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_security_group.id]
  }

  name            = "ecs-task"
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
}

# Create a security group
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-test-security-group"
  vpc_id      = "vpc-8f8856f2"
  description = "ECS Security Group"
  lifecycle {
    ignore_changes = all
  }

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
  subnets            = ["subnet-836b2f8d", "subnet-ec81d3a1"]  

  security_groups = [aws_security_group.ecs_security_group.id]
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-test-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-8f8856f2"  
  lifecycle {
    ignore_changes = all
  }

  health_check {
    path = "/"
    port = 80
  }
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_lb.ecs_load_balancer.arn}" 
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.ecs_target_group.arn}" 
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "testecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
  lifecycle {
    ignore_changes = all
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
