/// Driver availability in a logistics zone (demo dashboard).
class ZoneDriverSummary {
  const ZoneDriverSummary({
    required this.id,
    required this.zone,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.isAvailable,
    this.driverName,
  });

  final String id;
  final String zone;
  final String vehicleType;
  final String vehiclePlate;
  final bool isAvailable;
  final String? driverName;
}
