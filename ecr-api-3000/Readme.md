# Express API サービス

このサービスは、AWSのFargateで動作するシンプルなExpressアプリケーションです。

## 概要

- ポート3000でHTTPリクエストを受け付けます
- ルートエンドポイント（"/"）へのGETリクエストに対して"Hello World"を返します

## セットアップ

```bash
# 依存関係のインストール
npm install

# 開発サーバーの起動
npm start
```

## Docker

```bash
# イメージのビルド
docker build -t ecr-api-3000 .

# コンテナの実行
docker run -p 3000:3000 ecr-api-3000
```

## AWS Fargate

このアプリケーションはAWS Fargateで実行するように設計されています。
