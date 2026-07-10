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
