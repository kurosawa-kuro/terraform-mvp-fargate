# terraform-mvp-fargate

AWS Fargateを使用してExpressアプリケーション（ポート3000）をシンプルにデプロイするためのTerraformプロジェクトです。

## プロジェクト概要

このプロジェクトは以下のリソースを作成します：

- ECSクラスタ
- 新しいVPC、サブネット、インターネットゲートウェイ
- セキュリティグループ（ポート3000へのアクセスを許可）
- Fargateタスク定義とサービス
- CloudWatchログの設定
- 必要なIAMロールと権限

## 前提条件

- AWS CLIがインストールされ、認証情報が設定されていること
- Terraformがインストールされていること（バージョン1.0以上推奨）
- ECRに`503561449641.dkr.ecr.ap-northeast-1.amazonaws.com/ecr-api-3000`イメージがプッシュされていること

## Makefileの使用方法

このプロジェクトには便利なMakeコマンドが含まれています。以下は主なコマンドの説明です：

### 基本コマンド

```bash
# Terraformの初期化
make init

# 変更計画の表示
make plan

# 変更の適用（自動承認）
make apply

# 変更の適用（確認あり）
make apply-confirm

# リソースの削除（自動承認）
make destroy

# リソースの削除（確認あり）
make destroy-confirm
```

### その他のコマンド

```bash
# Terraformファイルのフォーマット
make fmt

# 構成の検証
make validate

# 一時ファイルの削除
make clean

# すべての操作をクリーンな状態から実行
make all

# 使用可能なコマンドの一覧表示
make help

# 環境変数の確認（デバッグ用）
make env
```

## 一般的なデプロイワークフロー

1. **初期化**: すべての必要なプロバイダーとモジュールをダウンロード
   ```bash
   make init
   ```

2. **計画**: 変更内容を確認
   ```bash
   make plan
   ```

3. **適用**: インフラストラクチャを作成
   ```bash
   make apply-confirm
   ```

4. **削除**: 使用後にすべてのリソースを削除（オプション）
   ```bash
   make destroy-confirm
   ```

## 注意点

- このデプロイはロードバランサーを含まないため、コンテナが再起動するとIPアドレスが変わる可能性があります
- デプロイ後、コンテナのパブリックIPアドレスとポート3000を使用してExpressアプリケーションにアクセスできます