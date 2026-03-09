const { trails, landmarks, wildlife } = require("./sampleData");

const db = {
  trails: [...trails],
  landmarks: [...landmarks],
  wildlife: [...wildlife],
  reviews: [],
  visitors: {},
  adminTrackLog: []
};

function getOrCreateVisitor(visitorId) {
  if (!db.visitors[visitorId]) {
    db.visitors[visitorId] = {
      visitorId,
      activity: {
        steps: 0,
        calories: 0,
        distanceKm: 0,
        elevationGainM: 0,
        updatedAt: new Date().toISOString()
      },
      notes: [],
      photos: [],
      comments: [],
      locations: []
    };
  }
  return db.visitors[visitorId];
}

module.exports = {
  db,
  getOrCreateVisitor
};
