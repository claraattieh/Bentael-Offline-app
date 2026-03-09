const API_BASE = "/api";
const visitorId = localStorage.getItem("bentaelVisitorId") || `visitor-${Math.floor(Math.random() * 10000)}`;
localStorage.setItem("bentaelVisitorId", visitorId);

const queueKey = "bentaelOfflineQueue";

const trailsGrid = document.getElementById("trailsGrid");
const landmarkList = document.getElementById("landmarkList");
const wildlifeList = document.getElementById("wildlifeList");
const reviewsList = document.getElementById("reviewsList");
const logsList = document.getElementById("logsList");
const adminList = document.getElementById("adminList");
const reviewTrailId = document.getElementById("reviewTrailId");
const connectionBadge = document.getElementById("connectionBadge");
const syncBtn = document.getElementById("syncBtn");

function getQueue() {
  return JSON.parse(localStorage.getItem(queueKey) || "[]");
}

function setQueue(items) {
  localStorage.setItem(queueKey, JSON.stringify(items));
  syncBtn.textContent = `Sync Pending (${items.length})`;
}

function enqueue(requestDef) {
  const queue = getQueue();
  queue.push(requestDef);
  setQueue(queue);
}

async function flushQueue() {
  if (!navigator.onLine) return;
  const queue = getQueue();
  if (!queue.length) return;
  const remaining = [];
  for (const requestDef of queue) {
    try {
      await fetch(requestDef.url, {
        method: requestDef.method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestDef.body)
      });
    } catch (error) {
      remaining.push(requestDef);
    }
  }
  setQueue(remaining);
}

async function postWithOfflineQueue(url, body) {
  if (!navigator.onLine) {
    enqueue({ method: "POST", url, body });
    return { queued: true };
  }
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error("Network response failed.");
    return response.json();
  } catch (error) {
    enqueue({ method: "POST", url, body });
    return { queued: true };
  }
}

async function loadTrails() {
  const response = await fetch(`${API_BASE}/trails`);
  const trails = await response.json();
  trailsGrid.innerHTML = trails
    .map(
      (trail) => `
      <article class="trail-card">
        <h3>${trail.name}</h3>
        <p>${trail.description}</p>
        <small>${trail.distanceKm} km | +${trail.elevationGainM}m | ETA ${trail.etaMin} min</small>
        <div class="chip">${trail.difficulty} - ${trail.status}</div>
      </article>
    `
    )
    .join("");

  reviewTrailId.innerHTML = trails.map((trail) => `<option value="${trail.id}">${trail.name}</option>`).join("");
}

async function loadLandmarks() {
  const response = await fetch(`${API_BASE}/landmarks`);
  const items = await response.json();
  landmarkList.innerHTML = items
    .map(
      (item) => `
      <li>
        <strong>${item.name}</strong><br />
        <small>${item.category}</small>
        <p>${item.summary}</p>
      </li>
    `
    )
    .join("");
}

async function loadWildlife() {
  const response = await fetch(`${API_BASE}/wildlife`);
  const items = await response.json();
  wildlifeList.innerHTML = items
    .map(
      (item) => `
      <li>
        <strong>${item.commonName}</strong><br />
        <small><em>${item.scientificName}</em> (${item.type})</small>
        <p>${item.conservationNote}</p>
      </li>
    `
    )
    .join("");
}

async function loadReviews() {
  const response = await fetch(`${API_BASE}/reviews`);
  const items = await response.json();
  reviewsList.innerHTML = items.length
    ? items
        .slice(0, 6)
        .map(
          (item) => `
      <li>
        <strong>${item.rating}/5</strong> on ${item.trailId}<br />
        <small>${new Date(item.createdAt).toLocaleString()}</small>
        <p>${item.text || "No comment."}</p>
      </li>
    `
        )
        .join("")
    : "<li>No reviews yet.</li>";
}

async function loadLogs() {
  const response = await fetch(`${API_BASE}/logs/${visitorId}`);
  const logs = await response.json();
  const merged = [
    ...logs.notes.map((i) => ({ ...i, type: "Note" })),
    ...logs.comments.map((i) => ({ ...i, type: "Comment" })),
    ...logs.photos.map((i) => ({ ...i, type: "Photo" }))
  ]
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, 8);

  logsList.innerHTML = merged.length
    ? merged
        .map(
          (entry) => `
      <li>
        <strong>${entry.type}</strong> <small>${new Date(entry.createdAt).toLocaleString()}</small>
        <p>${entry.text || "(No text)"}</p>
        ${entry.photoUrl ? `<a href="${entry.photoUrl}" target="_blank" rel="noreferrer">Open photo</a>` : ""}
      </li>
    `
        )
        .join("")
    : "<li>No personal logs yet.</li>";
}

async function loadAdminSnapshot() {
  const response = await fetch(`${API_BASE}/admin/visitors`);
  const snapshot = await response.json();
  adminList.innerHTML = snapshot.length
    ? snapshot
        .map(
          (item) => `
      <li>
        <strong>${item.visitorId}</strong>
        <p>Activity: ${item.activity.steps} steps, ${item.activity.distanceKm} km</p>
        <p>Logs: ${item.notesCount} notes, ${item.commentsCount} comments, ${item.photosCount} photos</p>
        <p>Latest location: ${
          item.latestLocation ? `${item.latestLocation.lat.toFixed(5)}, ${item.latestLocation.lng.toFixed(5)}` : "No data"
        }</p>
      </li>
    `
        )
        .join("")
    : "<li>No tracked visitors yet.</li>";
}

function updateNetworkBadge() {
  connectionBadge.textContent = navigator.onLine ? "Online" : "Offline (queue active)";
  connectionBadge.style.background = navigator.onLine ? "rgba(72, 187, 120, 0.25)" : "rgba(255, 193, 7, 0.25)";
}

document.getElementById("activityForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = {
    steps: Number(document.getElementById("steps").value),
    calories: Number(document.getElementById("calories").value),
    distanceKm: Number(document.getElementById("distanceKm").value),
    elevationGainM: Number(document.getElementById("elevationGainM").value)
  };
  await postWithOfflineQueue(`${API_BASE}/activity/${visitorId}`, payload);
  event.target.reset();
  await loadAdminSnapshot();
});

document.getElementById("reviewForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = {
    visitorId,
    trailId: reviewTrailId.value,
    rating: Number(document.getElementById("reviewRating").value),
    text: document.getElementById("reviewText").value
  };
  await postWithOfflineQueue(`${API_BASE}/reviews`, payload);
  event.target.reset();
  await loadReviews();
});

document.getElementById("logForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = {
    type: document.getElementById("logType").value,
    text: document.getElementById("logText").value,
    photoUrl: document.getElementById("logPhotoUrl").value
  };
  await postWithOfflineQueue(`${API_BASE}/logs/${visitorId}`, payload);
  event.target.reset();
  await loadLogs();
});

document.getElementById("sendTrackBtn").addEventListener("click", async () => {
  if (!navigator.geolocation) {
    alert("Browser geolocation is unavailable.");
    return;
  }
  navigator.geolocation.getCurrentPosition(
    async (position) => {
      await postWithOfflineQueue(`${API_BASE}/admin/track/${visitorId}`, {
        lat: position.coords.latitude,
        lng: position.coords.longitude,
        heading: position.coords.heading || 0,
        speedMps: position.coords.speed || 0
      });
      await loadAdminSnapshot();
    },
    () => alert("Location access denied or unavailable.")
  );
});

syncBtn.addEventListener("click", async () => {
  await flushQueue();
  await Promise.all([loadReviews(), loadLogs(), loadAdminSnapshot()]);
});

window.addEventListener("online", async () => {
  updateNetworkBadge();
  await flushQueue();
  await Promise.all([loadReviews(), loadLogs(), loadAdminSnapshot()]);
});
window.addEventListener("offline", updateNetworkBadge);

async function init() {
  updateNetworkBadge();
  setQueue(getQueue());
  await Promise.all([loadTrails(), loadLandmarks(), loadWildlife(), loadReviews(), loadLogs(), loadAdminSnapshot()]);
}

init();
