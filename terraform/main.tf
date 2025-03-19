provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}

# 共通変数の定義
locals {
  prefix        = "api-3000-02"
  account_id    = "503561449641"
  region        = "ap-northeast-1"
  ecr_repo_name = "ecr-api-3000"
  ecr_image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.ecr_repo_name}"
  
  # SSMパラメータのプレフィックス
  ssm_prefix    = "/${local.prefix}"
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
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${local.region}a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.prefix}-public-subnet-a"
  }
}

# 3.1 追加のパブリックサブネット (マルチAZ構成のため)
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${local.region}c"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.prefix}-public-subnet-c"
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
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# 7. ECS用セキュリティグループ作成
resource "aws_security_group" "ecs_sg" {
  name        = "${local.prefix}-ecs-sg"
  description = "Allow inbound traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.prefix}-ecs-sg"
  }
}

# 7.1 ALB用セキュリティグループ作成
resource "aws_security_group" "alb_sg" {
  name        = "${local.prefix}-alb-sg"
  description = "Allow inbound traffic on HTTP"
  vpc_id      = aws_vpc.main.id

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
  
  tags = {
    Name = "${local.prefix}-alb-sg"
  }
}

# 7.2 ECS SGにALBからのトラフィックを許可するルール
resource "aws_security_group_rule" "allow_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow traffic from ALB to ECS container"
}

# 8. Fargateタスク定義作成
resource "aws_ecs_task_definition" "express_task" {
  family                   = "${local.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${local.prefix}-container"
    image     = local.ecr_image
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
    secrets = [
      {
        name      = "BACKEND_PORT",
        valueFrom = aws_ssm_parameter.backend_port.arn
      },
      {
        name      = "FRONTEND_PORT",
        valueFrom = aws_ssm_parameter.frontend_port.arn
      },
      {
        name      = "DATABASE_URL",
        valueFrom = aws_ssm_parameter.database_url.arn
      },
      {
        name      = "JWT_SECRET_KEY",
        valueFrom = aws_ssm_parameter.jwt_secret_key.arn
      },
      {
        name      = "NODE_ENV",
        valueFrom = aws_ssm_parameter.node_env.arn
      },
      {
        name      = "UPLOAD_DIR",
        valueFrom = aws_ssm_parameter.upload_dir.arn
      }
    ],
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

# ALB作成
resource "aws_lb" "app_alb" {
  name               = "${local.prefix}-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  security_groups    = [aws_security_group.alb_sg.id]
  
  tags = {
    Name = "${local.prefix}-alb"
  }
}

# ターゲットグループ作成
resource "aws_lb_target_group" "express_tg" {
  name        = "${local.prefix}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    protocol            = "HTTP"
    path                = "/healthcheck"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
  
  tags = {
    Name = "${local.prefix}-tg"
  }
}

# ALBリスナー作成
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.express_tg.arn
  }
  
  tags = {
    Name = "${local.prefix}-http-listener"
  }
}

# 12. Fargateサービス作成
resource "aws_ecs_service" "express_service" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.express_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.express_tg.arn
    container_name   = "${local.prefix}-container"
    container_port   = 3000
  }
  
  depends_on = [
    aws_lb_listener.http
  ]
}

# 13. アウトプット
output "service_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
  description = "ALBのDNS名（APIサービスのURL）"
}

# SSM Parameter Storeパラメータの作成
resource "aws_ssm_parameter" "backend_port" {
  name        = "${local.ssm_prefix}/BACKEND_PORT"
  description = "Backend application port"
  type        = "String"
  value       = "8000"
}

resource "aws_ssm_parameter" "frontend_port" {
  name        = "${local.ssm_prefix}/FRONTEND_PORT"
  description = "Frontend application port"
  type        = "String"
  value       = "3000"
}

resource "aws_ssm_parameter" "database_url" {
  name        = "${local.ssm_prefix}/DATABASE_URL"
  description = "Database connection URL"
  type        = "SecureString"
  value       = "postgresql://postgres:postgres@localhost:5432/dev_db"
}

resource "aws_ssm_parameter" "jwt_secret_key" {
  name        = "${local.ssm_prefix}/JWT_SECRET_KEY"
  description = "JWT secret key for authentication"
  type        = "SecureString"
  value       = "secret"
}

resource "aws_ssm_parameter" "node_env" {
  name        = "${local.ssm_prefix}/NODE_ENV"
  description = "Node environment"
  type        = "String"
  value       = "production"
}

resource "aws_ssm_parameter" "upload_dir" {
  name        = "${local.ssm_prefix}/UPLOAD_DIR"
  description = "Upload directory path"
  type        = "String"
  value       = "uploads"
}

# SSMパラメータへのアクセス権限をIAMポリシーに追加
resource "aws_iam_policy" "ssm_parameter_access" {
  name        = "${local.prefix}-ssm-parameter-access"
  description = "Allow access to SSM parameters"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter${local.ssm_prefix}/*"
      }
    ]
  })
}

# SSMポリシーをECS実行ロールにアタッチ
resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ssm_parameter_access.arn
}
