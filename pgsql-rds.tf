resource "aws_db_subnet_group" "postgres_subnet_group" {
  name = "postgres-subnet-group"
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
    aws_subnet.private_3.id
  ]

  tags = {
    Name    = "postgres-subnet-group"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_security_group" "postgres_sg" {
  name        = "postgres-security-group"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.auth_ecs_task_sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "postgres-sg"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "lgr-postgres-db"

  engine         = "postgres"
  engine_version = "17.2"

  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"
  storage_encrypted     = false

  db_name  = "lgrdb"
  username = "postgres"
  password = var.database_password

  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet_group.name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  publicly_accessible    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  performance_insights_enabled = false
  monitoring_interval          = 0

  deletion_protection = false
  skip_final_snapshot = true

  parameter_group_name = "default.postgres17"

  tags = {
    Name    = "lgr-postgres-db"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_ssm_parameter" "database_url_rds" {
  name        = "/auth-service/database_url"
  description = "Database connection URL for RDS PostgreSQL"
  type        = "SecureString"
  value       = "postgresql://postgres:${var.database_password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
}
