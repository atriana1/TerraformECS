provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_access_key
  region     = var.region
}

resource "aws_vpc" "arroyo_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "arroyo_subnet" {
  vpc_id                  = aws_vpc.arroyo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_ecs_cluster" "my_cluster_arroyo" {
  name = "my_cluster_arroyo"
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role_arroyo.arn

  container_definitions = jsonencode([{
    name  = "arroyo-container",
    image = "nginx:latest",
    portMappings = [{
      containerPort = 80,
      hostPort      = 80,
    }],
  }])
}

resource "aws_ecs_service" "arroyo_service" {
  name            = "arroyo_service"
  cluster         = aws_ecs_cluster.my_cluster_arroyo.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.arroyo_subnet.id]
    assign_public_ip = true
  }
}

resource "aws_iam_role" "ecs_execution_role_arroyo" {
  name = "ecs-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com",
      },
    }],
  })
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds_sg_"

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Cambia esto a las direcciones IP permitidas
  }
}

resource "aws_db_instance" "arroyo_rds_mssql" {
  allocated_storage    = 20
  storage_type        = "standard"
  engine              = "sqlserver-ex"
  instance_class      = "db.t3.small"
  skip_final_snapshot = true
  # db_name             = "arroyodb"
  username            = "admin"
  password            = "Colombia2023."
  
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # parameter_group_name = "default.sqlserver-ex-15.00"  
}

output "ecs_publicip" {
  value = aws_ecs_service.arroyo_service.network_configuration
}

output "rds_endpoint" {
  value = aws_db_instance.arroyo_rds_mssql.endpoint
}



