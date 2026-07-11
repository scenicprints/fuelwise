/// Data models + efficiency math for FuelWise.
library;

class Vehicle {
  final String id;
  String name;
  int? year;
  String? make;
  double? tankGallons;

  Vehicle({
    required this.id,
    required this.name,
    this.year,
    this.make,
    this.tankGallons,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'year': year,
        'make': make,
        'tankGallons': tankGallons,
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        name: j['name'] as String,
        year: (j['year'] as num?)?.toInt(),
        make: j['make'] as String?,
        tankGallons: (j['tankGallons'] as num?)?.toDouble(),
      );
}

class FillUp {
  final String id;
  String vehicleId;
  DateTime date;
  double odometer; // miles
  double gallons;
  double pricePerGallon;
  String? station;
  bool partial;
  String? note;

  FillUp({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.gallons,
    required this.pricePerGallon,
    this.station,
    this.partial = false,
    this.note,
  });

  double get cost => gallons * pricePerGallon;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'gallons': gallons,
        'pricePerGallon': pricePerGallon,
        'station': station,
        'partial': partial,
        'note': note,
      };

  factory FillUp.fromJson(Map<String, dynamic> j) => FillUp(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        date: DateTime.parse(j['date'] as String),
        odometer: (j['odometer'] as num).toDouble(),
        gallons: (j['gallons'] as num).toDouble(),
        pricePerGallon: (j['pricePerGallon'] as num).toDouble(),
        station: j['station'] as String?,
        partial: (j['partial'] as bool?) ?? false,
        note: j['note'] as String?,
      );
}

/// Per-fill computed result (MPG is only defined for full fills that close an
/// interval since the previous full fill).
class FillComputed {
  final double? mpg;
  final double? milesInterval;
  const FillComputed(this.mpg, this.milesInterval);
}

class VehicleStats {
  final double? avgMpg;
  final double? costPerMile;
  final double? lastMpg;
  final double totalSpent;
  final double totalMiles;
  final double totalGallonsAll;
  final double? avgPricePerGallon;
  final int count;
  final List<double> mpgSeries; // chronological, one per closed interval
  final Map<String, FillComputed> perFill;

  const VehicleStats({
    required this.avgMpg,
    required this.costPerMile,
    required this.lastMpg,
    required this.totalSpent,
    required this.totalMiles,
    required this.totalGallonsAll,
    required this.avgPricePerGallon,
    required this.count,
    required this.mpgSeries,
    required this.perFill,
  });

  static const empty = VehicleStats(
    avgMpg: null,
    costPerMile: null,
    lastMpg: null,
    totalSpent: 0,
    totalMiles: 0,
    totalGallonsAll: 0,
    avgPricePerGallon: null,
    count: 0,
    mpgSeries: [],
    perFill: {},
  );
}

/// Standard "full-tank" MPG method: miles between two full fills divided by the
/// fuel added to get there. Partial fills don't close an interval — their
/// gallons roll into the next full fill so the math stays honest.
VehicleStats computeStats(List<FillUp> input) {
  if (input.isEmpty) return VehicleStats.empty;

  final fills = [...input]..sort((a, b) {
      final c = a.odometer.compareTo(b.odometer);
      return c != 0 ? c : a.date.compareTo(b.date);
    });

  double? lastFullOdo;
  double accGal = 0;
  double totalMiles = 0;
  double totalGalIntervals = 0;
  double totalCostIntervals = 0;
  double totalSpent = 0;
  double totalGalAll = 0;
  double accCost = 0;
  double? lastMpg;
  final series = <double>[];
  final perFill = <String, FillComputed>{};

  for (final f in fills) {
    totalSpent += f.cost;
    totalGalAll += f.gallons;
    accGal += f.gallons;
    accCost += f.cost;

    if (!f.partial) {
      if (lastFullOdo != null) {
        final miles = f.odometer - lastFullOdo;
        if (miles > 0 && accGal > 0) {
          final mpg = miles / accGal;
          series.add(mpg);
          lastMpg = mpg;
          totalMiles += miles;
          totalGalIntervals += accGal;
          totalCostIntervals += accCost;
          perFill[f.id] = FillComputed(mpg, miles);
        }
      }
      lastFullOdo = f.odometer;
      accGal = 0;
      accCost = 0;
    }
  }

  return VehicleStats(
    avgMpg: totalGalIntervals > 0 ? totalMiles / totalGalIntervals : null,
    costPerMile: totalMiles > 0 ? totalCostIntervals / totalMiles : null,
    lastMpg: lastMpg,
    totalSpent: totalSpent,
    totalMiles: totalMiles,
    totalGallonsAll: totalGalAll,
    avgPricePerGallon: totalGalAll > 0 ? totalSpent / totalGalAll : null,
    count: fills.length,
    mpgSeries: series,
    perFill: perFill,
  );
}

// ---- lightweight formatting helpers (avoids an intl dependency for now) ----

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String money(num v) => '\$${v.toStringAsFixed(2)}';

String mpg1(num? v) => v == null ? '–' : v.toStringAsFixed(1);

String num1(num? v) => v == null ? '–' : v.toStringAsFixed(1);

String duration(double hours) {
  if (hours <= 0) return '–';
  final total = (hours * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h <= 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// A saved trip estimate. Fuel/cost/time/stops are derived from the inputs.
class Trip {
  final String id;
  String label;
  double distance; // miles
  double mpg;
  double pricePerGallon;
  double speedMph;
  double? tankGallons;
  DateTime createdAt;

  Trip({
    required this.id,
    required this.label,
    required this.distance,
    required this.mpg,
    required this.pricePerGallon,
    required this.speedMph,
    this.tankGallons,
    required this.createdAt,
  });

  double get gallons => mpg > 0 ? distance / mpg : 0;
  double get fuelCost => gallons * pricePerGallon;
  double get hours => speedMph > 0 ? distance / speedMph : 0;

  int get stops {
    final tank = tankGallons;
    if (tank == null || tank <= 0 || mpg <= 0) return 0;
    final range = tank * mpg;
    if (range <= 0) return 0;
    final s = (distance / range).ceil() - 1;
    return s < 0 ? 0 : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'distance': distance,
        'mpg': mpg,
        'pricePerGallon': pricePerGallon,
        'speedMph': speedMph,
        'tankGallons': tankGallons,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? 'Trip',
        distance: (j['distance'] as num).toDouble(),
        mpg: (j['mpg'] as num).toDouble(),
        pricePerGallon: (j['pricePerGallon'] as num).toDouble(),
        speedMph: (j['speedMph'] as num?)?.toDouble() ?? 60,
        tankGallons: (j['tankGallons'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// An automatically-logged drive, split into city vs highway from the OBD
/// speed trace. Fuel is integrated from the airflow sensor (0 in pure EV).
class Drive {
  final String id;
  String vehicleId;
  DateTime start;
  DateTime end;
  double cityMiles;
  double highwayMiles;
  double cityGallons;
  double highwayGallons;
  double? minBattery; // % (hybrid battery life PID, if available)
  double? maxBattery;

  Drive({
    required this.id,
    required this.vehicleId,
    required this.start,
    required this.end,
    this.cityMiles = 0,
    this.highwayMiles = 0,
    this.cityGallons = 0,
    this.highwayGallons = 0,
    this.minBattery,
    this.maxBattery,
  });

  double get miles => cityMiles + highwayMiles;
  double get gallons => cityGallons + highwayGallons;
  double get minutes => end.difference(start).inSeconds / 60.0;
  double get avgMph => minutes > 0 ? miles / (minutes / 60.0) : 0;

  // MPG getters return null when effectively electric (negligible fuel burned).
  double? get mpg => gallons > 0.01 ? miles / gallons : null;
  double? get cityMpg => cityGallons > 0.01 ? cityMiles / cityGallons : null;
  double? get highwayMpg =>
      highwayGallons > 0.01 ? highwayMiles / highwayGallons : null;

  /// Share of miles driven on electric (no fuel) — a nice hybrid stat.
  double get evShare {
    if (miles <= 0) return 0;
    // Approximate: miles where fuel was ~0. We don't track per-segment EV, so
    // estimate from overall burn vs a nominal gas-only baseline is unreliable;
    // instead report 0 here and rely on per-drive mpg. Kept for future use.
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'cityMiles': cityMiles,
        'highwayMiles': highwayMiles,
        'cityGallons': cityGallons,
        'highwayGallons': highwayGallons,
        'minBattery': minBattery,
        'maxBattery': maxBattery,
      };

  factory Drive.fromJson(Map<String, dynamic> j) => Drive(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        cityMiles: (j['cityMiles'] as num?)?.toDouble() ?? 0,
        highwayMiles: (j['highwayMiles'] as num?)?.toDouble() ?? 0,
        cityGallons: (j['cityGallons'] as num?)?.toDouble() ?? 0,
        highwayGallons: (j['highwayGallons'] as num?)?.toDouble() ?? 0,
        minBattery: (j['minBattery'] as num?)?.toDouble(),
        maxBattery: (j['maxBattery'] as num?)?.toDouble(),
      );
}

/// Aggregate city/highway stats across drives.
class DriveStats {
  final double cityMiles;
  final double highwayMiles;
  final double? cityMpg;
  final double? highwayMpg;
  final double? overallMpg;
  final int count;
  final List<double> mpgSeries; // per-drive overall mpg, oldest -> newest

  const DriveStats({
    required this.cityMiles,
    required this.highwayMiles,
    required this.cityMpg,
    required this.highwayMpg,
    required this.overallMpg,
    required this.count,
    required this.mpgSeries,
  });

  static const empty = DriveStats(
    cityMiles: 0,
    highwayMiles: 0,
    cityMpg: null,
    highwayMpg: null,
    overallMpg: null,
    count: 0,
    mpgSeries: [],
  );
}

DriveStats computeDriveStats(List<Drive> drives) {
  if (drives.isEmpty) return DriveStats.empty;
  double cMi = 0, hMi = 0, cGal = 0, hGal = 0;
  final ordered = [...drives]..sort((a, b) => a.start.compareTo(b.start));
  final series = <double>[];
  for (final d in ordered) {
    cMi += d.cityMiles;
    hMi += d.highwayMiles;
    cGal += d.cityGallons;
    hGal += d.highwayGallons;
    final m = d.mpg;
    if (m != null) series.add(m);
  }
  final totMi = cMi + hMi, totGal = cGal + hGal;
  return DriveStats(
    cityMiles: cMi,
    highwayMiles: hMi,
    cityMpg: cGal > 0.01 ? cMi / cGal : null,
    highwayMpg: hGal > 0.01 ? hMi / hGal : null,
    overallMpg: totGal > 0.01 ? totMi / totGal : null,
    count: drives.length,
    mpgSeries: series,
  );
}
