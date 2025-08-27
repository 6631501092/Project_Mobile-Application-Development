// ===== index.js (simple; no helpers, uses ./db with mysql2) =====
const express = require("express");
const bcrypt  = require("bcrypt");
const con     = require("./db");   // your mysql2 createConnection

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/password/:pass", (req, res) => {
  bcrypt.hash(req.params.pass, 10, (e, hash) => {
    if (e) return res.status(500).send("Hashing error");
    res.send(hash);
  });
});

// Login
app.post("/login", (req, res) => {
  const { username, password } = req.body;
  const sql = "SELECT `id`,`username`,`password` FROM `users` WHERE `username`=?";
  con.query(sql, [username], (err, rows) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database server error" });
    if (rows.length !== 1) return res.status(401).json({ ok:false, error:"Wrong username" });

    bcrypt.compare(password, rows[0].password, (e, ok) => {
      if (e) return res.status(500).json({ ok:false, error:"Hashing error" });
      if (!ok) return res.status(401).json({ ok:false, error:"Wrong password" });
      res.json({ ok:true, userId: rows[0].id, username: rows[0].username });
    });
  });
});

// All expenses
app.get("/expenses", (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ ok:false, error:"userId required" });

  const sql = "SELECT `id`,`item`,`paid`,`date` FROM `expense` WHERE `user_id`=? ORDER BY `date`,`id`";
  con.query(sql, [userId], (err, rows) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database error" });
    const total = rows.reduce((s, r) => s + (Number(r.paid) || 0), 0);
    res.json({ ok:true, items: rows, total });
  });
});

// Today's expenses
app.get("/expenses/today", (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ ok:false, error:"userId required" });

  const sql = "SELECT `id`,`item`,`paid`,`date` FROM `expense` WHERE `user_id`=? AND DATE(`date`)=CURDATE() ORDER BY `date`,`id`";
  con.query(sql, [userId], (err, rows) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database error" });
    const total = rows.reduce((s, r) => s + (Number(r.paid) || 0), 0);
    res.json({ ok:true, items: rows, total });
  });
});

// Search (substring, case-insensitive)
app.get("/expenses/search", (req, res) => {
  const { userId, q } = req.query;
  if (!userId || !q) return res.status(400).json({ ok:false, error:"userId and q required" });

  const sql = "SELECT `id`,`item`,`paid`,`date` FROM `expense` WHERE `user_id`=? AND `item` LIKE ? COLLATE utf8mb4_general_ci ORDER BY `date`,`id`";
  con.query(sql, [userId, `%${q}%`], (err, rows) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database error" });
    const total = rows.reduce((s, r) => s + (Number(r.paid) || 0), 0);
    res.json({ ok:true, items: rows, total }); // client can ignore total for search
  });
});

// Add (server time)
app.post("/expenses", (req, res) => {
  let { userId, item, amount } = req.body; // client sends "amount"
  if (!userId || !item || amount === undefined) {
    return res.status(400).json({ ok:false, error:"userId, item, amount required" });
  }
  amount = parseInt(amount, 10);
  if (Number.isNaN(amount)) return res.status(400).json({ ok:false, error:"amount must be number" });

  const sql = "INSERT INTO `expense` (`user_id`,`item`,`paid`,`date`) VALUES (?,?,?,NOW())";
  con.query(sql, [userId, item, amount], (err, result) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database error" });
    res.json({ ok:true, id: result.insertId });
  });
});

// Delete
app.delete("/expenses/:id", (req, res) => {
  const { userId } = req.query;
  const { id } = req.params;
  if (!userId) return res.status(400).json({ ok:false, error:"userId required" });

  const sql = "DELETE FROM `expense` WHERE `id`=? AND `user_id`=?";
  con.query(sql, [id, userId], (err, result) => {
    if (err) return res.status(500).json({ ok:false, error: err.sqlMessage || "Database error" });
    if (result.affectedRows === 0) return res.status(404).json({ ok:false, error:"Not found" });
    res.json({ ok:true });
  });
});

const PORT = 3000;
app.listen(PORT, () => console.log('Server is running at ' + PORT));
