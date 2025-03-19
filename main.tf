provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}

# 1. ECSクラスタ作成
resource "aws_ecs_cluster" "default" {
  name = "api-3000-cluster"
}

# 2. VPC設定
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "api-3000-vpc"
  }
}

# 3. パブリックサブネット作成
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "api-3000-public-subnet"
  }
}

# 4. インターネットゲートウェイ作成
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "api-3000-igw"
  }
}

# 5. ルートテーブル作成
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "api-3000-public-rt"
  }
}

# 6. サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 7. セキュリティグループ作成
resource "aws_security_group" "ecs_sg" {
  name        = "api-3000-sg"
  description = "Allow inbound traffic on port 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "api-3000-sg"
  }
}

# 8. Fargateタスク定義作成
resource "aws_ecs_task_definition" "express_task" {
  family                   = "api-3000-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "api-3000-container"
    image     = "503561449641.dkr.ecr.ap-northeast-1.amazonaws.com/ecr-api-3000"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.express_logs.name
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 9. CloudWatch Logs設定
resource "aws_cloudwatch_log_group" "express_logs" {
  name              = "/ecs/api-3000"
  retention_in_days = 7
}

# 10. IAMロール作成
resource "aws_iam_role" "ecs_execution_role" {
  name = "api-3000-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# 11. IAMポリシーアタッチ
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 12. Fargateサービス作成
resource "aws_ecs_service" "express_service" {
  name            = "api-3000-service"
  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.express_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}

# 13. アウトプット
output "service_url" {
  value = "http://${aws_ecs_service.express_service.network_configuration[0].assign_public_ip}:3000"
  description = "API 3000のURL（注：IPアドレスはサービス起動後に確認してください）"
}
