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

resource "aws_ecs_task_definition" "TDD" {
  family                   = "Nginx-TDD"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name      = "main-container"
      image     = "612958166077.dkr.ecr.us-east-1.amazonaws.com/test:new"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}


data "aws_ecs_task_definition" "TDD" {
  task_definition = aws_ecs_task_definition.TDD.family
}

resource "aws_ecs_service" "ecs-service" {
  name                               = "First-Service"
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  cluster                            = aws_ecs_cluster.test.id
  task_definition                    = aws_ecs_task_definition.TDD.arn
  scheduling_strategy                = "REPLICA"
  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  #depends_on                         = [aws_alb_listener.Listener, aws_iam_role.iam-role]


  load_balancer {
    target_group_arn = "${aws_lb_target_group.ecs_target_group.arn}"
    container_name   = "main-container"
    container_port   = 80
  }


  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_security_group.id]
    subnets          = ["subnet-836b2f8d", "subnet-ec81d3a1"]
  }
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
  internal           = false
  subnets            = ["subnet-836b2f8d", "subnet-ec81d3a1"]  

  security_groups = [aws_security_group.ecs_security_group.id]
  tags = {
    Name = "L and L"
  }
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-test-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-8f8856f2"  

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

  statement {
    actions   = ["ecr:*"]
    resources = ["*"]
  }

  statement {
    actions   = [
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:DescribeContainerInstances",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:CreateCluster",
      "ecs:RegisterTaskDefinition",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:SetRulePriorities"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecsTaskExecutionPolicy" {
  name   = "ecsTaskExecutionPolicy"
  policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_custom_policy_attachment" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = aws_iam_policy.ecsTaskExecutionPolicy.arn
}

