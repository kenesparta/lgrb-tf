resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name = "redis-subnet-group"
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
    aws_subnet.private_3.id
  ]

  tags = {
    Name    = "redis-subnet-group"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "redis-sg"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_security_group_rule" "redis_from_auth_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis_sg.id
  source_security_group_id = aws_security_group.auth_ecs_task_sg.id
}


resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "lgr-redis-cluster"
  description          = "Redis cluster for LGR project"

  node_type            = "cache.t4g.micro"
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters = 1

  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  multi_az_enabled           = false
  automatic_failover_enabled = false

  snapshot_retention_limit = 0

  engine_version = "7.0"

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = {
    Name    = "lgr-redis-cluster"
    Project = var.project
    Owner   = var.owner
  }
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "/redis/endpoint"
  description = "Redis cluster endpoint"
  type        = "String"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address != null ? aws_elasticache_replication_group.redis.configuration_endpoint_address : aws_elasticache_replication_group.redis.primary_endpoint_address

  tags = {
    Name    = "redis-endpoint"
    Project = var.project
    Owner   = var.owner
  }
}
