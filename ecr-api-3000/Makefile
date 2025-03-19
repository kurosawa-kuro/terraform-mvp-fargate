# ECR API 3000 - Makefile
# 環境変数の設定
ECR_REPO = 503561449641.dkr.ecr.ap-northeast-1.amazonaws.com/ecr-api-3000
AWS_REGION = ap-northeast-1
IMAGE_NAME = ecr-api-3000
IMAGE_TAG = latest
APP_PORT = 3000

# ヘルプ
help:
	@echo "使用可能なコマンド:"
	@echo "Node.jsアプリケーション:"
	@echo "  make setup           - package.jsonの初期化とExpressのインストール"
	@echo "  make start           - アプリケーションの起動"
	@echo "  make dev             - nodemonを使用した開発モードでの起動"
	@echo ""
	@echo "ECRコマンド:"
	@echo "  make ecr-login       - ECRレジストリへのログイン"
	@echo "  make ecr-build       - Dockerイメージのビルド"
	@echo "  make ecr-tag         - イメージにタグを付ける"
	@echo "  make docker-stop     - 実行中のコンテナを停止"
	@echo "  make ecr-push        - イメージをECRにプッシュ"
	@echo "  make ecr-deploy      - ログイン、ビルド、タグ付け、プッシュの全工程を実行"
	@echo ""
	@echo "ファイル生成:"
	@echo "  make setup           - 必要なファイルをすべて生成"

# Node.js関連コマンド
setup:
	npm init -y
	npm install express
	npm install --save-dev nodemon

start:
	node app.js

# ECR関連コマンド
ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REPO)

ecr-build:
	docker build -t $(IMAGE_NAME) .

ecr-tag:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(ECR_REPO):$(IMAGE_TAG)

docker-stop:
	docker stop $$(docker ps -q --filter ancestor=$(IMAGE_NAME):$(IMAGE_TAG)) 2>/dev/null || echo "実行中のコンテナがありません"

ecr-push:
	docker push $(ECR_REPO):$(IMAGE_TAG)

ecr-deploy: ecr-login ecr-build ecr-tag ecr-push
	@echo "ECRへのデプロイが完了しました"

# デフォルトコマンド
.PHONY: help setup start dev ecr-login ecr-build ecr-tag docker-stop ecr-push ecr-deploy

.DEFAULT_GOAL := help
