resource "aws_ecs_task_definition" "auth_service" {
  family                   = "auth-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service",
      image     = "kenesparta/lgr-auth-service:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 3000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "auth_service" {
  cluster         = aws_ecs_cluster.lgr_service_cluster.id
  name            = "auth-service"
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.auth_service.arn

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
    container_name   = "auth-service"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.auth_https_listener]
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
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.lgr_auth_service_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "auth_service_alb" {
  name               = "auth-service-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lgr_auth_service_sg.id]
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id,
  ]
}

resource "aws_lb_listener" "auth_https_listener" {
  load_balancer_arn = aws_lb.auth_service_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.lgr_web_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_service_tg.arn
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

resource "aws_lb_target_group" "auth_service_tg" {
  name        = "auth-service-tg"
  port        = 3000
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
