const path = require("path");
const express = require("express");
const cors = require("cors");
const { db, getOrCreateVisitor } = require("./store");

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json({ limit: "2mb" }));

const frontendPath = path.resolve(__dirname, "../../frontend");
app.use(express.static(frontendPath));
app.use("/brand-assets", express.static(path.resolve(__dirname, "../../../assets/logo")));

app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    app: "Bentael Guide API",
    version: "draft-1",
    serverTime: new Date().toISOString()
  });
});

app.get("/api/trails", (req, res) => res.json(db.trails));
app.get("/api/landmarks", (req, res) => res.json(db.landmarks));
app.get("/api/wildlife", (req, res) => res.json(db.wildlife));
app.get("/api/reviews", (req, res) => res.json(db.reviews));

app.post("/api/reviews", (req, res) => {
  const { visitorId, trailId, rating, text } = req.body || {};
  if (!visitorId || !trailId || !rating) {
    return res.status(400).json({ error: "visitorId, trailId, and rating are required." });
  }
  const item = {
    id: `rvw-${Date.now()}`,
    visitorId,
    trailId,
    rating: Number(rating),
    text: text || "",
    createdAt: new Date().toISOString()
  };
  db.reviews.unshift(item);
  return res.status(201).json(item);
});

app.get("/api/activity/:visitorId", (req, res) => {
  const visitor = getOrCreateVisitor(req.params.visitorId);
  res.json(visitor.activity);
});

app.post("/api/activity/:visitorId", (req, res) => {
  const visitor = getOrCreateVisitor(req.params.visitorId);
  const payload = req.body || {};
  visitor.activity = {
    steps: Number(payload.steps || 0),
    calories: Number(payload.calories || 0),
    distanceKm: Number(payload.distanceKm || 0),
    elevationGainM: Number(payload.elevationGainM || 0),
    updatedAt: new Date().toISOString()
  };
  res.status(201).json(visitor.activity);
});

app.get("/api/logs/:visitorId", (req, res) => {
  const visitor = getOrCreateVisitor(req.params.visitorId);
  res.json({
    notes: visitor.notes,
    photos: visitor.photos,
    comments: visitor.comments
  });
});

app.post("/api/logs/:visitorId", (req, res) => {
  const visitor = getOrCreateVisitor(req.params.visitorId);
  const { type, text, photoUrl } = req.body || {};
  if (!type) {
    return res.status(400).json({ error: "type is required: note | comment | photo" });
  }
  const entry = {
    id: `log-${Date.now()}`,
    text: text || "",
    photoUrl: photoUrl || "",
    createdAt: new Date().toISOString()
  };
  if (type === "note") visitor.notes.unshift(entry);
  else if (type === "comment") visitor.comments.unshift(entry);
  else if (type === "photo") visitor.photos.unshift(entry);
  else return res.status(400).json({ error: "Invalid type. Use note, comment, or photo." });
  return res.status(201).json(entry);
});

app.post("/api/admin/track/:visitorId", (req, res) => {
  const visitor = getOrCreateVisitor(req.params.visitorId);
  const { lat, lng, heading, speedMps } = req.body || {};
  if (typeof lat !== "number" || typeof lng !== "number") {
    return res.status(400).json({ error: "lat and lng must be numbers." });
  }
  const trackPoint = {
    visitorId: visitor.visitorId,
    lat,
    lng,
    heading: Number(heading || 0),
    speedMps: Number(speedMps || 0),
    recordedAt: new Date().toISOString()
  };
  visitor.locations.unshift(trackPoint);
  db.adminTrackLog.unshift(trackPoint);
  res.status(201).json(trackPoint);
});

app.get("/api/admin/visitors", (req, res) => {
  const snapshot = Object.values(db.visitors).map((v) => ({
    visitorId: v.visitorId,
    latestLocation: v.locations[0] || null,
    activity: v.activity,
    notesCount: v.notes.length,
    commentsCount: v.comments.length,
    photosCount: v.photos.length
  }));
  res.json(snapshot);
});

app.get("*", (req, res) => {
  res.sendFile(path.join(frontendPath, "index.html"));
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Bentael Guide draft server running on http://localhost:${PORT}`);
});
