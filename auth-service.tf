locals {
  auth_rest_port   = 3000
  auth_grpc_port   = 50051
  internal_dns_api = "auth-service.local"
}

resource "aws_ecs_task_definition" "auth_service_restAPI" {
  family                   = "auth-service-restAPI"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service-restAPI",
      image     = "kenesparta/lgr-auth-service:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = local.auth_rest_port
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.auth_service_restAPI_logs
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs-auth-restAPI"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "auth_service_gRPC" {
  family                   = "auth-service-gRPC"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service-gRPC",
      image     = "kenesparta/lgr-auth-service:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = local.auth_grpc_port
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.auth_service_gRPC_logs
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs-auth-gRPC"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "auth_service_restAPI" {
  cluster         = aws_ecs_cluster.lgr_service_cluster.id
  name            = "auth-service-restAPI"
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.auth_service_restAPI.arn

  network_configuration {
    subnets = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.public_3.id,
    ]
    security_groups  = [aws_security_group.auth_ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_service_tg.arn
    container_name   = "auth-service-restAPI"
    container_port   = local.auth_rest_port
  }

  depends_on = [
    aws_lb_listener.auth_https_listener
  ]
}

resource "aws_ecs_service" "auth_service_gRPC" {
  cluster         = aws_ecs_cluster.lgr_service_cluster.id
  name            = "auth-service-gRPC"
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.auth_service_gRPC.arn

  network_configuration {
    subnets = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.public_3.id,
    ]
    security_groups  = [aws_security_group.auth_ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grpc_service_tg.arn
    container_name   = "auth-service-gRPC"
    container_port   = local.auth_grpc_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth_discovery.arn
  }

  depends_on = [
    aws_lb_listener.auth_https_listener
  ]
}

resource "aws_security_group" "lgr_auth_service_sg" {
  name        = "auth-service-alb"
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

resource "aws_security_group" "auth_ecs_task_sg" {
  name        = "auth-ecs-task-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = local.auth_rest_port
    to_port         = local.auth_rest_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lgr_auth_service_sg.id]
  }

  ingress {
    from_port = local.auth_grpc_port
    to_port   = local.auth_grpc_port
    protocol  = "tcp"
    security_groups = [
      aws_security_group.lgr_auth_service_sg.id,
      aws_security_group.app_ecs_task_sg.id,
      aws_security_group.lgr_app_service_sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "auth_service_alb" {
  name                       = "auth-service-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lgr_auth_service_sg.id]
  enable_deletion_protection = false
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id,
  ]

  tags = {
    Name    = "auth-lb"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_lb_target_group" "auth_service_tg" {
  name        = "auth-service-tg"
  port        = local.auth_rest_port
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

  tags = {
    Name = "auth-api-rest"
  }
}

resource "aws_lb_target_group" "grpc_service_tg" {
  name             = "grpc-service-tg"
  port             = local.auth_grpc_port
  protocol         = "HTTP"
  vpc_id           = aws_vpc.main.id
  target_type      = "ip"
  protocol_version = "GRPC"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "12"
    path                = "/AWS.ALB/healthcheck"
    protocol            = "HTTP"
  }

  tags = {
    Name = "auth-gRPC"
  }
}

resource "aws_lb_listener" "auth_https_listener" {
  load_balancer_arn = aws_lb.auth_service_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.lgr_web_certificate.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "grpc_rule" {
  listener_arn = aws_lb_listener.auth_https_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grpc_service_tg.arn
  }

  condition {
    host_header {
      values = ["grpc.${var.main_dns}"]
    }
  }
}

resource "aws_lb_listener_rule" "api_rest_rule" {
  listener_arn = aws_lb_listener.auth_https_listener.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_service_tg.arn
  }

  condition {
    host_header {
      values = ["auth.${var.main_dns}"]
    }
  }
}

resource "aws_lb_listener" "auth_http_listener" {
  load_balancer_arn = aws_lb.auth_service_alb.arn
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

resource "aws_service_discovery_private_dns_namespace" "auth_namespace" {
  name        = local.internal_dns_api
  vpc         = aws_vpc.main.id
  description = "Private DNS for auth service"
}

resource "aws_service_discovery_service" "auth_discovery" {
  name = "auth-service-gRPC"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.auth_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_cloudwatch_log_group" "auth_service_restAPI_logs" {
  name              = "/ecs/aut-service-restAPI"
  retention_in_days = 1

  tags = {
    Name = "auth-restAPI-logs"
  }
}

resource "aws_cloudwatch_log_group" "auth_service_gRPC_logs" {
  name              = "/ecs/aut-service-gRPC"
  retention_in_days = 1

  tags = {
    Name = "auth-gRPC-logs"
  }
}
