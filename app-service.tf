locals {
  app_rest_port = 8000
}

resource "aws_ecs_task_definition" "app_service" {
  family                   = "app-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app-service",
      image     = "kenesparta/lgr-app-service:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = local.app_rest_port
        }
      ],
      environment = [
        {
          name  = "AUTH_SERVICE_HOST"
          value = "https://auth.${var.main_dns}"
        },
        {
          name = "GRPC_AUTH_SERVICE_HOST"
          # TODO: Should be an internal DNS, not external to be more fast
          # value = "http://${aws_service_discovery_service.auth_discovery.name}.${local.internal_dns_api}:${local.auth_grpc_port}"
          value = "https://grpc.${var.main_dns}"
        }
      ],

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app_service_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs-app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app_service" {
  cluster         = aws_ecs_cluster.lgr_service_cluster.id
  name            = "app-service"
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.app_service.arn

  network_configuration {
    subnets = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.public_3.id,
    ]
    security_groups  = [aws_security_group.app_ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_service_tg.arn
    container_name   = "app-service"
    container_port   = local.app_rest_port
  }

  depends_on = [aws_lb_listener.app_https_listener]
}

resource "aws_security_group" "lgr_app_service_sg" {
  name        = "app-service-alb"
  description = "Allow container traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_ecs_task_sg" {
  name        = "app-ecs-task-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = local.app_rest_port
    to_port         = local.app_rest_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lgr_app_service_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_service_alb" {
  name                       = "app-service-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lgr_app_service_sg.id]
  enable_deletion_protection = false
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id,
  ]
  tags = {
    Name    = "app-lb"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_lb_listener" "app_https_listener" {
  load_balancer_arn = aws_lb.app_service_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.lgr_web_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_service_tg.arn
  }
}

resource "aws_lb_listener" "app_http_listener" {
  load_balancer_arn = aws_lb.app_service_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "app_service_tg" {
  name        = "app-service-tg"
  port        = local.app_rest_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health-check"
    matcher             = "200"
    protocol            = "HTTP"
  }
}

resource "aws_cloudwatch_log_group" "app_service_logs" {
  name              = "/ecs/app-service"
  retention_in_days = 1

  tags = {
    Name = "app-logs"
  }
}
