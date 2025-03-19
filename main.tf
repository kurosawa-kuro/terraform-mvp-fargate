provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}

# 共通変数の定義
locals {
  prefix        = "api-3000"
  account_id    = "503561449641"
  region        = "ap-northeast-1"
  ecr_repo_name = "ecr-api-3000"
  ecr_image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.ecr_repo_name}"
}

# 1. ECSクラスタ作成
resource "aws_ecs_cluster" "default" {
  name = "${local.prefix}-cluster"
}

# 2. VPC設定
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# 3. パブリックサブネット作成
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${local.region}a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.prefix}-public-subnet"
  }
}

# 4. インターネットゲートウェイ作成
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${local.prefix}-igw"
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
    Name = "${local.prefix}-public-rt"
  }
}

# 6. サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 7. セキュリティグループ作成
resource "aws_security_group" "ecs_sg" {
  name        = "${local.prefix}-sg"
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
    Name = "${local.prefix}-sg"
  }
}

# 8. Fargateタスク定義作成
resource "aws_ecs_task_definition" "express_task" {
  family                   = "${local.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${local.prefix}-container"
    image     = local.ecr_image
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
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 9. CloudWatch Logs設定
resource "aws_cloudwatch_log_group" "express_logs" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = 7
}

# 10. IAMロール作成
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.prefix}-execution-role"
  
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
  name            = "${local.prefix}-service"
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
  description = "${local.prefix}のURL（注：IPアドレスはサービス起動後に確認してください）"
}
