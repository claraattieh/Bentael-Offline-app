const trails = [
  {
    id: "trail-cedar-oak",
    name: "Cedar & Oak Loop",
    difficulty: "Easy",
    distanceKm: 2.6,
    etaMin: 55,
    elevationGainM: 110,
    status: "Open",
    description:
      "Gentle loop through mixed oak and pine sections, suitable for beginner hikers and families."
  },
  {
    id: "trail-st-john",
    name: "St. John Hermitage Trail",
    difficulty: "Moderate",
    distanceKm: 3.2,
    etaMin: 90,
    elevationGainM: 190,
    status: "Open",
    description:
      "Historic route toward the St. John rock-cut hermitage, with moderate climbs and viewpoints."
  },
  {
    id: "trail-raptor-ridge",
    name: "Raptor Ridge Traverse",
    difficulty: "Moderate",
    distanceKm: 4.3,
    etaMin: 125,
    elevationGainM: 270,
    status: "Open",
    description:
      "Birdwatching-focused traverse along ridges known for migratory raptor sightings in season."
  },
  {
    id: "trail-full-circuit",
    name: "Full Reserve Circuit",
    difficulty: "Hard",
    distanceKm: 5.8,
    etaMin: 175,
    elevationGainM: 360,
    status: "Open",
    description:
      "Long full-reserve route for experienced hikers seeking complete terrain coverage."
  }
];

const landmarks = [
  {
    id: "lm-hermitage",
    name: "St. John Hermitage",
    category: "Historical",
    lat: 34.1406,
    lng: 35.6941,
    summary: "12th-century rock-cut hermitage and chapel carved into the reserve's limestone formation."
  },
  {
    id: "lm-upper-gate",
    name: "Upper Bentael Entrance",
    category: "Access Point",
    lat: 34.1436,
    lng: 35.6965,
    summary: "Primary upper access with convenient link to central reserve trails."
  },
  {
    id: "lm-mechehlene-gate",
    name: "Mechehlene Entrance",
    category: "Access Point",
    lat: 34.1379,
    lng: 35.6919,
    summary: "Lower entrance often used by day-hikers starting loop routes."
  }
];

const wildlife = [
  {
    id: "fauna-raptor",
    commonName: "Migratory Raptors",
    scientificName: "Accipitridae spp.",
    type: "Bird",
    conservationNote: "Observed seasonally along migration corridors passing over Bentael."
  },
  {
    id: "flora-oak",
    commonName: "Kermes Oak",
    scientificName: "Quercus calliprinos",
    type: "Plant",
    conservationNote: "Dominant native oak species in compact limestone zones."
  },
  {
    id: "flora-pine",
    commonName: "Stone Pine",
    scientificName: "Pinus pinea",
    type: "Plant",
    conservationNote: "Common in planted and recovering areas of the reserve."
  }
];

module.exports = {
  trails,
  landmarks,
  wildlife
};
