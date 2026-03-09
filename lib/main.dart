import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const BentaelHikerApp());
}

class BentaelHikerApp extends StatelessWidget {
  const BentaelHikerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D32);
    return MaterialApp(
      title: 'Bentael Hiker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F9F3),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Distance _distanceCalc = const Distance();

  List<TrailRoute> _routes = const [];
  List<ReserveExit> _exits = const [];
  TrailRoute? _selectedRoute;
  Position? _position;
  String _status = 'Loading local reserve data...';
  bool _loading = true;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadLocalData();
    await _startLocation();
  }

  Future<void> _loadLocalData() async {
    try {
      final raw = await rootBundle.loadString('assets/data/bentael_tracks.json');
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;

      final routes = (jsonMap['routes'] as List<dynamic>)
          .map((r) => TrailRoute.fromJson(r as Map<String, dynamic>))
          .toList();
      final exits = (jsonMap['exits'] as List<dynamic>)
          .map((e) => ReserveExit.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _routes = routes;
        _exits = exits;
        _selectedRoute = routes.isNotEmpty ? routes.first : null;
        _status = 'Offline data loaded.';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _status = 'Failed to read local tracks. Check assets/data/bentael_tracks.json';
        _loading = false;
      });
    }
  }

  Future<void> _startLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'Enable location services to track your hike.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _status = 'Location permission is required for live tracking.');
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((p) {
      setState(() {
        _position = p;
        _status = 'Tracking live (offline-ready).';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final userPoint = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
    final center = userPoint ?? const LatLng(34.14034, 35.69357);

    final stats = route == null || userPoint == null
        ? null
        : _computeRouteStats(route: route, user: userPoint);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              status: _status,
              onOpenOfficialMap: _openOfficialMap,
              onRecenter: () async {
                final pos = await Geolocator.getCurrentPosition();
                setState(() => _position = pos);
              },
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15.2,
                  minZoom: 12,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  // Offline-first map canvas (no network tiles).
                  PolylineLayer(
                    polylines: _routes
                        .map(
                          (r) => Polyline(
                            points: r.points,
                            strokeWidth: r.id == route?.id ? 5 : 3,
                            color: r.id == route?.id ? r.color : r.color.withOpacity(0.72),
                          ),
                        )
                        .toList(),
                  ),
                  MarkerLayer(
                    markers: [
                      ..._exits.map(
                        (e) => Marker(
                          point: e.point,
                          width: 130,
                          height: 40,
                          child: _ExitChip(name: e.name),
                        ),
                      ),
                      ..._routes.map(
                        (r) => Marker(
                          point: r.points.first,
                          width: 140,
                          height: 34,
                          child: _RouteLabel(name: r.name),
                        ),
                      ),
                      if (userPoint != null)
                        Marker(
                          point: userPoint,
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0D47A1),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _BottomPanel(
              loading: _loading,
              routes: _routes,
              selectedRouteId: route?.id,
              onRouteSelected: (id) {
                setState(() {
                  _selectedRoute = _routes.firstWhere((r) => r.id == id);
                });
              },
              liveStats: stats,
              nearestExit: userPoint == null || _exits.isEmpty ? null : _nearestExit(userPoint),
            ),
          ],
        ),
      ),
    );
  }

  ReserveExit _nearestExit(LatLng user) {
    ReserveExit nearest = _exits.first;
    double best = _metersBetween(user, nearest.point);
    for (final e in _exits.skip(1)) {
      final d = _metersBetween(user, e.point);
      if (d < best) {
        best = d;
        nearest = e;
      }
    }
    return nearest;
  }

  LiveStats _computeRouteStats({
    required TrailRoute route,
    required LatLng user,
  }) {
    final points = route.points;
    if (points.length < 2) {
      return LiveStats.empty();
    }

    final nearestResult = _nearestOnRoute(points, user);
    final rawRemainingKm = _remainingDistanceKm(points, nearestResult.segmentIndex, nearestResult.projectedPoint);
    final polylineKm = _polylineDistanceKm(points);
    final routeKm = route.lengthKm;
    final remainingKm = polylineKm <= 0 ? rawRemainingKm : rawRemainingKm * (routeKm / polylineKm);
    final completed = max(0.0, routeKm - remainingKm);
    final progress = routeKm == 0 ? 0.0 : (completed / routeKm).clamp(0.0, 1.0);
    final userKmh = (_position?.speed ?? 0) * 3.6;
    final effectiveSpeed = userKmh > 1.5 ? userKmh : route.avgSpeedKmh;
    final etaMinutes = effectiveSpeed <= 0 ? 0 : ((remainingKm / effectiveSpeed) * 60).round();
    final offRouteMeters = nearestResult.offRouteMeters;
    final offRoute = offRouteMeters > 35;

    return LiveStats(
      remainingKm: remainingKm,
      progress: progress,
      etaMinutes: etaMinutes,
      offRouteMeters: offRouteMeters,
      offRoute: offRoute,
    );
  }

  _NearestProjection _nearestOnRoute(List<LatLng> route, LatLng user) {
    var bestDistance = double.infinity;
    var bestPoint = route.first;
    var bestSegment = 0;

    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      final projected = _projectOnSegment(user, a, b);
      final d = _metersBetween(projected, user);
      if (d < bestDistance) {
        bestDistance = d;
        bestPoint = projected;
        bestSegment = i;
      }
    }

    return _NearestProjection(
      segmentIndex: bestSegment,
      projectedPoint: bestPoint,
      offRouteMeters: bestDistance,
    );
  }

  double _remainingDistanceKm(List<LatLng> route, int segmentIndex, LatLng projectedPoint) {
    var meters = 0.0;
    meters += _metersBetween(projectedPoint, route[segmentIndex + 1]);
    for (var i = segmentIndex + 1; i < route.length - 1; i++) {
      meters += _metersBetween(route[i], route[i + 1]);
    }
    return meters / 1000.0;
  }

  double _polylineDistanceKm(List<LatLng> route) {
    if (route.length < 2) return 0;
    var meters = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      meters += _metersBetween(route[i], route[i + 1]);
    }
    return meters / 1000.0;
  }

  LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final ab2 = abx * abx + aby * aby;
    if (ab2 == 0) return a;

    var t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);
    return LatLng(ay + aby * t, ax + abx * t);
  }

  double _metersBetween(LatLng a, LatLng b) => _distanceCalc.as(LengthUnit.Meter, a, b);

  void _openOfficialMap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE8EFE6),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.84,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: Color(0xFF1B5E20)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Official Bentael Trail Map (Offline)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Image.asset('assets/maps/bentael_official_trails_full.png', fit: BoxFit.contain),
                        const SizedBox(height: 12),
                        Image.asset('assets/maps/bentael_official_trails_zoom.png', fit: BoxFit.contain),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.status,
    required this.onOpenOfficialMap,
    required this.onRecenter,
  });

  final String status;
  final VoidCallback onOpenOfficialMap;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset('assets/logo/bentael_logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bentael Hiker',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenOfficialMap,
            tooltip: 'Official map',
            icon: const Icon(Icons.image_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: onRecenter,
            icon: const Icon(Icons.my_location_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.loading,
    required this.routes,
    required this.selectedRouteId,
    required this.onRouteSelected,
    required this.liveStats,
    required this.nearestExit,
  });

  final bool loading;
  final List<TrailRoute> routes;
  final String? selectedRouteId;
  final void Function(String routeId) onRouteSelected;
  final LiveStats? liveStats;
  final ReserveExit? nearestExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [BoxShadow(blurRadius: 9, color: Color(0x15000000))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final r = routes[i];
                final selected = r.id == selectedRouteId;
                return GestureDetector(
                  onTap: () => onRouteSelected(r.id),
                  child: Container(
                    width: 215,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE8F5E9) : const Color(0xFFF4F8F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFF2E7D32) : const Color(0xFFDDE7DB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${r.lengthKm.toStringAsFixed(2)} km • ${r.difficulty} • +${r.elevationGainM} m',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3E5948)),
                        ),
                        Text(
                          'Avg: ${r.paceMinPerKm.toStringAsFixed(0)} min/km • ETA: ${r.estimatedDurationMin} min',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3E5948)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (liveStats != null)
            Row(
              children: [
                _Stat(
                  title: 'Remaining',
                  value: '${liveStats!.remainingKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 8),
                _Stat(
                  title: 'ETA',
                  value: '${liveStats!.etaMinutes} min',
                ),
                const SizedBox(width: 8),
                _Stat(
                  title: 'Progress',
                  value: '${(liveStats!.progress * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                liveStats?.offRoute == true ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: liveStats?.offRoute == true ? Colors.orange : const Color(0xFF2E7D32),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  liveStats == null
                      ? 'Waiting for GPS...'
                      : liveStats!.offRoute
                          ? 'You are ~${liveStats!.offRouteMeters.toStringAsFixed(0)}m off-route.'
                          : 'On route. Nearest exit: ${nearestExit?.name ?? '-'}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF6FBF5),
          border: Border.all(color: const Color(0xFFDFEBDD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF4A6355))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ExitChip extends StatelessWidget {
  const _ExitChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F3DC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC5B88A)),
        ),
        child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF9FC49A)),
        ),
        child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class TrailRoute {
  const TrailRoute({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.lengthKm,
    required this.elevationGainM,
    required this.estimatedDurationMin,
    required this.avgSpeedKmh,
    required this.color,
    required this.points,
  });

  final String id;
  final String name;
  final String difficulty;
  final double lengthKm;
  final int elevationGainM;
  final int estimatedDurationMin;
  final double avgSpeedKmh;
  final Color color;
  final List<LatLng> points;

  double get paceMinPerKm => lengthKm <= 0 ? 0 : estimatedDurationMin / lengthKm;

  factory TrailRoute.fromJson(Map<String, dynamic> json) {
    return TrailRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      difficulty: json['difficulty'] as String,
      lengthKm: (json['length_km'] as num).toDouble(),
      elevationGainM: (json['elevation_gain_m'] as num).toInt(),
      estimatedDurationMin: (json['estimated_duration_min'] as num).toInt(),
      avgSpeedKmh: json['avg_speed_kmh'] == null
          ? ((json['length_km'] as num).toDouble() / ((json['estimated_duration_min'] as num).toDouble() / 60.0))
          : (json['avg_speed_kmh'] as num).toDouble(),
      color: _colorFromHex((json['color_hex'] as String?) ?? '#2E7D32'),
      points: (json['points'] as List<dynamic>)
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
    );
  }

  static Color _colorFromHex(String hexColor) {
    final clean = hexColor.replaceAll('#', '');
    final withAlpha = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.parse(withAlpha, radix: 16));
  }
}

class ReserveExit {
  const ReserveExit({
    required this.id,
    required this.name,
    required this.point,
  });

  final String id;
  final String name;
  final LatLng point;

  factory ReserveExit.fromJson(Map<String, dynamic> json) {
    return ReserveExit(
      id: json['id'] as String,
      name: json['name'] as String,
      point: LatLng(
        (json['point'][0] as num).toDouble(),
        (json['point'][1] as num).toDouble(),
      ),
    );
  }
}

class LiveStats {
  const LiveStats({
    required this.remainingKm,
    required this.progress,
    required this.etaMinutes,
    required this.offRouteMeters,
    required this.offRoute,
  });

  final double remainingKm;
  final double progress;
  final int etaMinutes;
  final double offRouteMeters;
  final bool offRoute;

  factory LiveStats.empty() => const LiveStats(
        remainingKm: 0,
        progress: 0,
        etaMinutes: 0,
        offRouteMeters: 0,
        offRoute: false,
      );
}

class _NearestProjection {
  const _NearestProjection({
    required this.segmentIndex,
    required this.projectedPoint,
    required this.offRouteMeters,
  });

  final int segmentIndex;
  final LatLng projectedPoint;
  final double offRouteMeters;
}
