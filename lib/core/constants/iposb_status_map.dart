/// Frozen SOP status codes (see integration/STATUS_MAP.md).
abstract final class IposbStatusMap {
  static const accept = 'ACC';
  static const pickedUp = 'PKU';
  static const arrivedHub = 'ARR';
  static const sorted = 'SRT';
  static const storekeeper = 'SHB';
  static const atHub = 'HUB';
  static const outForDelivery = 'OFD';
  static const withCourier = 'DRS';
  static const delivered = 'POD';
  static const undelivered = 'UND';
  static const overnight = 'OVN';
  static const selfCollect = 'SCF';
  static const returnReg = 'RTN';

  static const pipelineActions = [
    accept,
    pickedUp,
    arrivedHub,
    sorted,
    storekeeper,
    outForDelivery,
    withCourier,
    delivered,
    undelivered,
  ];

  static const pickupActions = [accept, pickedUp, atHub, arrivedHub];
  static const deliveryActions = [
    withCourier,
    outForDelivery,
    delivered,
    undelivered,
  ];

  static String labelOf(String code) => switch (code.toUpperCase()) {
        accept => 'Accept / assign',
        pickedUp => 'Pickup from seller',
        arrivedHub => 'Arrive at hub (normal path)',
        sorted => 'Sort (SBH325/326)',
        storekeeper => 'Storekeeper receive',
        atHub => 'Hub handoff (skip sort)',
        outForDelivery => 'Out for delivery',
        withCourier => 'With courier (DRS)',
        delivered => 'Delivered (POD)',
        undelivered => 'Undelivered',
        overnight => 'Overnight scan',
        selfCollect => 'Self-collection',
        returnReg => 'Return registration',
        _ => code,
      };

  /// Customer-facing tracking labels (web + future customer app).
  static String customerLabelOf(String code) => switch (code.toUpperCase()) {
        'BDE' || accept => 'Pending Pickup',
        pickedUp => 'Collected',
        arrivedHub || 'GWD' || atHub || sorted || 'INB' || 'MNF' => 'In Transit',
        storekeeper || outForDelivery || withCourier || selfCollect =>
          'To Be Delivered',
        delivered || 'PCC' || 'PFP' || 'PCB' => 'Signed / Delivered',
        undelivered || overnight || 'N13' || 'N12' || 'N9' || 'UTL' =>
          'Problematic / Delayed',
        returnReg || 'RTS' => 'Returning to Sender',
        _ => 'In Transit',
      };

  /// Detailed timeline sentence, e.g. "Parcel arrived at SBH325 hub".
  static String detailLabelOf(
    String code, {
    String? location,
    String? note,
  }) {
    final key = code.toUpperCase().trim();
    final hub = (location ?? '').toUpperCase().trim();
    final atHub = hub.isNotEmpty ? ' at $hub hub' : ' at hub';
    final from = hub.isNotEmpty ? ' from $hub' : '';
    final via = hub.isNotEmpty ? ' via $hub' : '';
    final paren = hub.isNotEmpty ? ' ($hub)' : '';

    var detail = switch (key) {
      'BDE' => 'Order created — waiting for pickup',
      'ACC' => hub.isNotEmpty
          ? 'Parcel assigned to courier at $hub'
          : 'Parcel assigned to courier',
      'PKU' => hub.isNotEmpty
          ? 'Parcel collected from seller ($hub)'
          : 'Parcel collected from seller',
      'GWD' => hub.isNotEmpty
          ? 'Parcel departed gateway ($hub)'
          : 'Parcel departed gateway',
      'ARR' || 'INB' => 'Parcel arrived$atHub',
      'SRT' || 'MNF' => hub.isNotEmpty
          ? 'Parcel sorting at $hub hub'
          : 'Parcel sorting at hub',
      'HUB' => 'Parcel handed over$atHub',
      'SHB' => hub.isNotEmpty
          ? 'Parcel received by storekeeper at $hub'
          : 'Parcel received by storekeeper',
      'OFD' => 'Parcel out for delivery$from',
      'DRS' => hub.isNotEmpty
          ? 'Parcel with courier for delivery ($hub)'
          : 'Parcel with courier for delivery',
      'SCF' => hub.isNotEmpty
          ? 'Parcel ready for self-collection at $hub'
          : 'Parcel ready for self-collection',
      'POD' || 'PCC' || 'PFP' || 'PCB' => 'Parcel delivered and signed$paren',
      'UND' || 'OVN' => hub.isNotEmpty
          ? 'Delivery attempt failed at $hub'
          : 'Delivery attempt failed',
      'RTN' || 'RTS' => 'Parcel returning to sender$via',
      'N13' || 'UTL' => 'Parcel delayed — location update pending',
      'N12' || 'N9' => 'Parcel reported damaged',
      _ => customerLabelOf(key),
    };

    final noteText = (note ?? '').trim();
    if (noteText.isNotEmpty &&
        !detail.toLowerCase().contains(noteText.toLowerCase()) &&
        !RegExp(
          r'^(ops:|ops desk|scanned via|mobile demo|driver scan)',
          caseSensitive: false,
        ).hasMatch(noteText)) {
      detail = '$detail — $noteText';
    }
    return detail;
  }

  /// Default hub when scan omits location (SOP KK demo flow).
  static String defaultLocForStatus(
    String code, {
    String? origin,
    String? dest,
  }) {
    final key = code.toUpperCase().trim();
    final from = (origin ?? 'BKI').toUpperCase().trim();
    final to = (dest ?? from).toUpperCase().trim();
    return switch (key) {
      'ARR' || 'SHB' || 'HUB' || 'SCF' => 'SBH325',
      'SRT' || 'MNF' => '805',
      'PKU' || 'ACC' || 'BDE' || 'GWD' => from.isNotEmpty ? from : 'BKI',
      'OFD' || 'DRS' || 'POD' || 'UND' || 'OVN' => to.isNotEmpty ? to : 'BKI',
      _ => to.isNotEmpty ? to : 'BKI',
    };
  }
}
