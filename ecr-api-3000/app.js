/**
 * アプリケーションエントリーポイント
 * 
 * このファイルは、Expressアプリケーションのメインエントリーポイントとなるもので、
 * 環境変数の設定、ルーティング、ミドルウェア、サービス、およびサーバー起動を管理します。
 */

// -----------------------------------------------------------------------------
// モジュールのインポート
// -----------------------------------------------------------------------------
const express = require("express");

// -----------------------------------------------------------------------------
// サービス層の定義
// -----------------------------------------------------------------------------
/**
 * アプリケーションサービス
 */
const appService = {
  /**
   * メインページのデータを取得する
   * @returns {Object} メインページに表示するデータ
   */
  getMainPageData: () => {
    return { message: "Hello World" };
  },

  /**
   * 環境変数情報を取得する
   * @returns {Object} 環境変数情報
   */
  getEnvironmentInfo: () => {
    return {
      application: {
        backendPort: process.env.BACKEND_PORT,
        frontendPort: process.env.FRONTEND_PORT
      },
      database: {
        url: process.env.DATABASE_URL
      },
      auth: {
        jwtSecretKey: process.env.JWT_SECRET_KEY,
        nodeEnv: process.env.NODE_ENV
      },
      upload: {
        uploadDir: process.env.UPLOAD_DIR
      }
    };
  }
};

// -----------------------------------------------------------------------------
// 環境変数の設定
// -----------------------------------------------------------------------------
/**
 * 環境変数を初期化する
 */
function setupEnvironmentVariables() {
  if (process.env.NODE_ENV !== 'production') {
    try {
      require('dotenv').config();
      console.log('.envファイルから環境変数を読み込みました');
    } catch (error) {
      console.log('dotenvモジュールがインストールされていないか、.envファイルがありません。環境変数を直接使用します。');
    }
  } else {
    console.log('本番環境のため、AWS SSMパラメータストアから環境変数を使用します');
  }
}

// -----------------------------------------------------------------------------
// コントローラー層の定義
// -----------------------------------------------------------------------------
/**
 * アプリケーションコントローラー
 */
const appController = {
  /**
   * メインページを表示する
   * @param {Object} req - リクエストオブジェクト
   * @param {Object} res - レスポンスオブジェクト
   */
  showMainPage: (req, res) => {
    console.log("Hello World");
    const data = appService.getMainPageData();
    res.send(data.message);
  }
};

// -----------------------------------------------------------------------------
// ルーティングの設定
// -----------------------------------------------------------------------------
/**
 * ルーティングを設定する
 * @param {Object} app - Expressアプリケーションインスタンス
 */
function setupRoutes(app) {
  app.get("/", appController.showMainPage);
}

// -----------------------------------------------------------------------------
// サーバー起動とロギングの設定
// -----------------------------------------------------------------------------
/**
 * 環境変数の情報をログに出力する
 */
function logEnvironmentInfo() {
  const envInfo = appService.getEnvironmentInfo();

  console.log("Github Action動作確認２２:");
  
  console.log("環境変数:");
  console.log("====================");
  console.log(`アプリケーションポート:`);
  console.log(`- BACKEND_PORT: ${envInfo.application.backendPort}`);
  console.log(`- FRONTEND_PORT: ${envInfo.application.frontendPort}`);
  console.log(`\nデータベース接続情報:`);
  console.log(`- DATABASE_URL: ${envInfo.database.url}`);
  console.log(`\n認証情報:`);
  console.log(`- JWT_SECRET_KEY: ${envInfo.auth.jwtSecretKey}`);
  console.log(`- NODE_ENV: ${envInfo.auth.nodeEnv}`);
  console.log(`\nアップロード設定:`);
  console.log(`- UPLOAD_DIR: ${envInfo.upload.uploadDir}`);
  console.log("====================");
}

/**
 * サーバーを起動する
 * @param {Object} app - Expressアプリケーションインスタンス
 */
function startServer(app) {
  const port = process.env.FRONTEND_PORT || 3000;
  
  app.listen(port, () => {
    logEnvironmentInfo();
    console.log(`サーバーはポート ${port} で起動しています`);
  });
}

// -----------------------------------------------------------------------------
// アプリケーションの初期化と起動
// -----------------------------------------------------------------------------
/**
 * アプリケーションを初期化し起動する
 */
function initializeApp() {
  // 環境変数のセットアップ
  setupEnvironmentVariables();
  
  // Expressアプリケーションの作成
  const app = express();
  
  // ルーティングの設定
  setupRoutes(app);
  
  // サーバーの起動
  startServer(app);
}

// アプリケーションを実行
initializeApp();
