const express = require("express");
const app = express();

app.get("/", (req, res) => {
  console.log("Hello World");
  res.send("Hello World");
});

app.listen(3000, () => {
  console.log("Server is running on port 3000");
});
