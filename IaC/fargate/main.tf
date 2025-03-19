#########################################
# プロバイダ設定 & ローカル変数
#########################################
provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}

locals {
  prefix        = "api-3000-ssm-04"
  account_id    = "503561449641"
  region        = "ap-northeast-1"
  ecr_repo_name = "ecr-api-3000"
  ecr_image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.ecr_repo_name}"

  # SSMパラメータのプレフィックス
  ssm_prefix = "/${local.prefix}"

  # 1.1 サブネット作成用に AZ と CIDR をまとめる
  public_subnets = {
    a = "10.0.1.0/24"
    c = "10.0.2.0/24"
  }
  
  # SSM パラメータのARNリスト
  ssm_parameter_keys = [
    "BACKEND_PORT",
    "FRONTEND_PORT",
    "DATABASE_URL",
    "JWT_SECRET_KEY",
    "NODE_ENV",
    "UPLOAD_DIR"
  ]
}

#########################################
# ECS クラスタ
#########################################
resource "aws_ecs_cluster" "default" {
  name = "${local.prefix}-cluster"
}

#########################################
# ネットワーク (VPC, Subnet, IGW, RouteTable)
#########################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# サブネット (for_eachで複数作成)
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${local.region}${each.key}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public-subnet-${each.key}"
  }
}

# Public Route Table
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

# サブネットとルートテーブルの関連付け (for_each)
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#########################################
# セキュリティグループ
#########################################
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

# ALB から ECS への通信を許可
resource "aws_security_group_rule" "allow_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow traffic from ALB to ECS container"
}

#########################################
# IAM ロール & ポリシー
#########################################
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.prefix}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM パラメータアクセス用のポリシー
data "aws_iam_policy" "ssm_parameter_access" {
  name = "${local.prefix}-ssm-parameter-access"
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = data.aws_iam_policy.ssm_parameter_access.arn
}

#########################################
# CloudWatch Logs
#########################################
resource "aws_cloudwatch_log_group" "express_logs" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = 7
}

#########################################
# ECS Task Definition (コンテナ設定)
#########################################
# SSM パラメータを secrets として渡す
locals {
  # タスク定義に渡す secrets を動的リスト化
  container_secrets = [
    for key in local.ssm_parameter_keys : {
      name      = key
      valueFrom = "arn:aws:ssm:${local.region}:${local.account_id}:parameter${local.ssm_prefix}/${key}"
    }
  ]
}

resource "aws_ecs_task_definition" "express_task" {
  family                   = "${local.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.prefix}-container"
      image     = local.ecr_image
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      # 上で動的生成した container_secrets をそのまま割り当て
      secrets = local.container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.express_logs.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

#########################################
# ALB (LB / TG / Listener)
#########################################
resource "aws_lb" "app_alb" {
  name               = "${local.prefix}-alb"
  load_balancer_type = "application"
  # for_each サブネットのIDを配列化
  subnets            = values(aws_subnet.public)[*].id
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = "${local.prefix}-alb"
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

resource "aws_lb_target_group" "express_tg" {
  name        = "${local.prefix}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/"
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.express_tg.arn
  }
}

#########################################
# ECS Service
#########################################
resource "aws_ecs_service" "express_service" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.express_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.public)[*].id
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

#########################################
# アウトプット
#########################################
output "service_url" {
  value       = "http://${aws_lb.app_alb.dns_name}"
  description = "ALBのDNS名（APIサービスのURL）"
}
