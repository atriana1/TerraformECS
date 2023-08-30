# *****************
# VPC Configuration
# *****************
resource "aws_vpc" "arroyo_ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "arroyo_ecs_igw" {
  vpc_id = aws_vpc.arroyo_ecs_vpc.id
}

# *********************
# SUBNETS Configuration
# *********************
resource "aws_subnet" "arroyo_subnet_1" {
  vpc_id                  = aws_vpc.arroyo_ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
}

resource "aws_subnet" "arroyo_subnet_2" {
  vpc_id                  = aws_vpc.arroyo_ecs_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
}

# *************************
# LoadBalance Configuration
# *************************
resource "aws_lb" "lb-ecs-arroyo" {
  name               = "lb-ecs-arroyo"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.arroyo_subnet_1.id, aws_subnet.arroyo_subnet_2.id] 
}

resource "aws_lb_target_group" "lb-target-ecs-arroyo" {
  name     = "lb-target-ecs-arroyo"
  port     = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = aws_vpc.arroyo_ecs_vpc.id
  
  depends_on = [aws_lb.lb-ecs-arroyo]
}

resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.lb-ecs-arroyo.arn
  port              = 80
  default_action {
    target_group_arn = aws_lb_target_group.lb-target-ecs-arroyo.arn
    type             = "forward"
  }
}

# *************************
# RouteTables Configuration
# *************************
resource "aws_route_table" "arroyo_ecs_route_table" {
  vpc_id = aws_vpc.arroyo_ecs_vpc.id
}

resource "aws_route" "arroyo_route" {
  route_table_id         = aws_route_table.arroyo_ecs_route_table.id
  destination_cidr_block = "0.0.0.0/0"  # Ruta por defecto para todo el tráfico
  gateway_id             = aws_internet_gateway.arroyo_ecs_igw.id
}

resource "aws_route_table_association" "arroyo_subnet_association1" {
  subnet_id      = aws_subnet.arroyo_subnet_1.id
  route_table_id = aws_route_table.arroyo_ecs_route_table.id
}

resource "aws_route_table_association" "arroyo_subnet_association2" {
  subnet_id      = aws_subnet.arroyo_subnet_2.id
  route_table_id = aws_route_table.arroyo_ecs_route_table.id
}

# ***************************
# SecurityGroup Configuration
# ***************************
resource "aws_security_group" "sg_arroyo_ecs" {
  name        = "ecs_sg"
  description = "Security group for ECS instance"
  vpc_id      = aws_vpc.arroyo_ecs_vpc.id

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

# ***********************
# ECS Configuration (Cluster, Task, Service, IAM Role)
# ***********************
resource "aws_ecs_cluster" "cluster_arroyo" {
  name = "cluster_arroyo"
}

resource "aws_ecs_task_definition" "arroyo_task_definition" {
  family                   = "arroyo_task_definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role_arroyo.arn

  container_definitions = jsonencode([{
    name  = "arroyo-container",
    image = "atriana1/arroyo_devops:1.0",
    portMappings = [{
      containerPort = 80,
      hostPort      = 80,
    }],
  }])

  depends_on = [aws_iam_role.ecs_execution_role_arroyo]
}

resource "aws_ecs_service" "arroyo_service" {
  name            = "arroyo_service"
  cluster         = aws_ecs_cluster.cluster_arroyo.id
  task_definition = aws_ecs_task_definition.arroyo_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets = [aws_subnet.arroyo_subnet_1.id, aws_subnet.arroyo_subnet_2.id]
    security_groups = [aws_security_group.sg_arroyo_ecs.id]
    assign_public_ip = true
  }  

  load_balancer {
    target_group_arn = aws_lb_target_group.lb-target-ecs-arroyo.arn
    container_name   = "arroyo-container"
    container_port   = 80
  }

  depends_on = [aws_security_group.sg_arroyo_ecs]
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