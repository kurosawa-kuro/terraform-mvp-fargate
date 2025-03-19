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
	@echo "  make create-app      - app.jsファイルの生成"
	@echo "  make create-dockerfile - Dockerfileの生成"
	@echo "  make create-all      - 必要なファイルをすべて生成"

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

# ファイル生成コマンド
create-app:
	@echo "const express = require(\"express\");" > app.js
	@echo "const app = express();" >> app.js
	@echo "" >> app.js
	@echo "app.get(\"/\", (req, res) => {" >> app.js
	@echo "  console.log(\"Hello World\");" >> app.js
	@echo "  res.send(\"Hello World\");" >> app.js
	@echo "});" >> app.js
	@echo "" >> app.js
	@echo "app.listen($(APP_PORT), () => {" >> app.js
	@echo "  console.log(\"Server is running on port $(APP_PORT)\");" >> app.js
	@echo "});" >> app.js
	@echo "app.jsファイルを生成しました"

create-dockerfile:
	@echo "FROM node:18-alpine" > Dockerfile
	@echo "" >> Dockerfile
	@echo "WORKDIR /app" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# package.jsonとpackage-lock.jsonのみをコピーして依存関係をインストール" >> Dockerfile
	@echo "COPY package*.json ./" >> Dockerfile
	@echo "RUN npm ci --only=production" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# アプリケーションのソースコードをコピー" >> Dockerfile
	@echo "COPY app.js ./" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# 非rootユーザーでアプリケーションを実行" >> Dockerfile
	@echo "USER node" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# アプリケーションが使用するポートを公開" >> Dockerfile
	@echo "EXPOSE $(APP_PORT)" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# ヘルスチェック" >> Dockerfile
	@echo "HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\" >> Dockerfile
	@echo "  CMD wget --no-verbose --tries=1 --spider http://localhost:$(APP_PORT)/ || exit 1" >> Dockerfile
	@echo "" >> Dockerfile
	@echo "# コンテナ起動時に実行するコマンド" >> Dockerfile
	@echo "CMD [\"node\", \"app.js\"]" >> Dockerfile
	@echo "Dockerfileを生成しました"

create-all: create-app create-dockerfile setup
	@echo "すべてのファイルを生成しました"

# デフォルトコマンド
.PHONY: help setup start dev ecr-login ecr-build ecr-tag docker-stop ecr-push ecr-deploy \
	create-app create-dockerfile create-all

.DEFAULT_GOAL := help
