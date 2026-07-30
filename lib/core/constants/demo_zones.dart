/// Sabah, Malaysia logistics zones for the routing table / create-shipment form.
///
/// Codes are stable IDs used in DB (`routing_rules`, staff `zone`, shipments).
/// [labelOf] is what operators see in the UI.
abstract final class DemoZones {
  static const kkMetro = 'KK-METRO';
  static const westCoast = 'WEST-COAST';
  static const interior = 'INTERIOR';
  static const sandakan = 'SANDAKAN';
  static const tawau = 'TAWAU';

  /// Default demo pair that matches the seeded routing rule + staff.
  static const demoOrigin = kkMetro;
  static const demoDestination = sandakan;

  static const List<String> all = [
    kkMetro,
    westCoast,
    interior,
    sandakan,
    tawau,
  ];

  static const Map<String, String> labels = {
    kkMetro: 'Kota Kinabalu Metro',
    westCoast: 'West Coast',
    interior: 'Interior',
    sandakan: 'Sandakan',
    tawau: 'Tawau / East Coast South',
  };

  static String labelOf(String code) => labels[code] ?? code;
}
