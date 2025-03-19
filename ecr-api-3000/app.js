// try {
//     require('dotenv').config();
//   } catch (error) {
//     console.log('dotenvモジュールがインストールされていないか、.envファイルがありません。環境変数を直接使用します。');
//   }

const express = require("express");
const app = express();

app.get("/", (req, res) => {
  console.log("Hello World");
  res.send("Hello World");
});

// 環境変数からポート番号を取得（デフォルト値:3000）
const port = process.env.FRONTEND_PORT || 3000;

app.listen(port, () => {
  // 環境変数の表示
  console.log("環境変数:");
  console.log("====================");
  console.log(`アプリケーションポート:`);
  console.log(`- BACKEND_PORT: ${process.env.BACKEND_PORT}`);
  console.log(`- FRONTEND_PORT: ${process.env.FRONTEND_PORT}`);
  console.log(`\nデータベース接続情報:`);
  console.log(`- DATABASE_URL: ${process.env.DATABASE_URL}`);
  console.log(`\n認証情報:`);
  console.log(`- JWT_SECRET_KEY: ${process.env.JWT_SECRET_KEY}`);
  console.log(`- NODE_ENV: ${process.env.NODE_ENV}`);
  console.log(`\nアップロード設定:`);
  console.log(`- UPLOAD_DIR: ${process.env.UPLOAD_DIR}`);
  console.log("====================");
  
  console.log(`サーバーはポート ${port} で起動しています`);
});
