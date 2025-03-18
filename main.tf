provider "aws" {
  region = " "
}

# 1. ECSクラスタ作成
resource "aws_ecs_cluster" "default" {
  name = "ecs-cluster"
}

# 2. Fargateタスク定義作成
resource "aws_ecs_task_definition" "express_task" {
  family                   = "express-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "express-container"
    image     = "your-ecr-repository-uri"  # ECRにプッシュしたイメージのURIを指定
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
  }])
}

# 3. Fargateサービス作成
resource "aws_ecs_service" "express_service" {
  name            = "express-service"
  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.express_task.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.default.id]
    assign_public_ip = true
  }
}

# 4. サブネット設定（デフォルトのサブネットを使用）
resource "aws_subnet" "default" {
  vpc_id                  = "vpc-xxxxxxxx" # デフォルトVPCのIDを指定
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
}

# 5. セキュリティグループ作成
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow inbound traffic on port 3000"
  vpc_id      = "vpc-xxxxxxxx" # デフォルトVPCのIDを指定

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
}
