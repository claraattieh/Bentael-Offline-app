# Bentael Hiker (Draft v1)

Offline-first Flutter app draft for hikers in **Bentael Nature Reserve (Lebanon)**.

## What this draft includes

- Nature-themed simple UI
- Built-in app logo (`assets/logo/bentael_logo.png`)
- Embedded official trail map images for offline reference (`assets/maps/`)
- Offline local dataset for routes + exits (`assets/data/bentael_tracks.json`)
- Live GPS tracking
- Route progress + remaining distance
- Dynamic ETA (uses live speed when available, otherwise route average speed)
- Off-route alert (distance from nearest route segment)
- Nearest-exit suggestion

## Source-backed reserve facts used

- Reserve location near Byblos/Jbeil
- Entrances A, B, and C from official Bentael trail map
- St. John rock-cut hermitage/chapel as a trail point of interest
- Trails #1-#5 lengths and time estimates from official map legend

## Important accuracy note

This is a **working draft**. Route geometry in `assets/data/bentael_tracks.json` should be validated with field GPX tracks before production use.

## Run locally

If this folder was empty before, run:

```bash
flutter create .
```

Then:

```bash
flutter pub get
flutter run
```

## Platform setup for GPS permissions

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

### iOS

Add to `ios/Runner/Info.plist`:

- `NSLocationWhenInUseUsageDescription` with a short reason, e.g.:
  - "Bentael Hiker uses your location to track hiking progress and ETA offline."

## Next recommended iteration

- Replace draft routes with verified GPX/KML tracks from reserve management
- Add offline tile package (MBTiles) for full cartographic basemap offline
- Add bilingual UI (Arabic/English)
- Add hazard points, water points, and ranger contacts
