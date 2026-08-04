/// Frozen SOP status codes (see integration/STATUS_MAP.md).
/// Includes Yoyi / drop-point self-collection path (CPA → SCN → CPI → POD).
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
  static const cpArrival = 'CPA';
  static const cpNotify = 'SCN';
  static const cpInbound = 'CPI';
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
    selfCollect,
    cpArrival,
  ];

  static const yoyiActions = [cpArrival, cpNotify, cpInbound, selfCollect, delivered];

  /// Yoyi abnormal outbound Y1–Y6 → suggested next IPOSB status.
  static const yoyiAbnormalNext = <String, String>{
    'Y1': returnReg, // reject / refuse pay
    'Y2': returnReg, // overdue self-collect
    'Y3': outForDelivery, // wants home delivery
    'Y4': undelivered, // other
    'Y5': 'N12', // damaged
    'Y6': 'N13', // lost
  };

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
        selfCollect => 'Self-collection (ready)',
        cpArrival => 'Yoyi CP arrival (consult)',
        cpNotify => 'Self-collect notice sent',
        cpInbound => 'Yoyi CP inbound (shelved)',
        returnReg => 'Return registration',
        _ => code,
      };

  /// Customer-facing short labels (chips / summary).
  static String customerLabelOf(String code) => switch (code.toUpperCase()) {
        'BDE' => 'Pending Pickup',
        accept => 'Courier Assigned',
        pickedUp => 'Collected',
        arrivedHub => 'Arrived at Hub',
        sorted => 'Sorting',
        atHub => 'At Hub',
        'GWD' || 'INB' || 'MNF' => 'In Transit',
        storekeeper => 'Preparing for Delivery',
        outForDelivery || withCourier => 'Out for Delivery',
        selfCollect || cpInbound => 'Ready for Self-Collection',
        cpArrival => 'At Collection Point',
        cpNotify => 'Self-Collection Notice Sent',
        delivered || 'PCC' || 'PFP' || 'PCB' => 'Delivered',
        undelivered => 'Delivery Unsuccessful',
        overnight || 'N13' || 'N12' || 'N9' || 'UTL' => 'Delivery Delayed',
        returnReg || 'RTS' => 'Returning to Sender',
        _ => 'In Transit',
      };

  /// Customer timeline sentence (no ops codes / internal notes).
  static String detailLabelOf(
    String code, {
    String? location,
    String? note,
  }) {
    final key = code.toUpperCase().trim();
    final place = friendlyPlace(location);
    final at = place.isNotEmpty ? ' at our $place' : '';
    final from = place.isNotEmpty ? ' from $place' : '';
    final inPlace = place.isNotEmpty ? ' in $place' : '';

    return switch (key) {
      'BDE' => 'Your order has been created and is waiting for pickup',
      'ACC' => 'A courier has been assigned to pick up your parcel',
      'PKU' => place.isNotEmpty
          ? 'Your parcel has been collected from the sender$inPlace'
          : 'Your parcel has been collected from the sender',
      'GWD' => place.isNotEmpty
          ? 'Your parcel has left our gateway facility$inPlace'
          : 'Your parcel is on the way to the next facility',
      'ARR' || 'INB' => place.isNotEmpty
          ? 'Your parcel has arrived$at'
          : 'Your parcel has arrived at our hub',
      'SRT' || 'MNF' => place.isNotEmpty
          ? 'Your parcel is being sorted$at'
          : 'Your parcel is being sorted at our hub',
      'HUB' => place.isNotEmpty
          ? 'Your parcel has been received$at'
          : 'Your parcel has been received at our hub',
      'SHB' => place.isNotEmpty
          ? 'Your parcel is at our $place and is being prepared for delivery'
          : 'Your parcel is being prepared for delivery at our hub',
      'OFD' => place.isNotEmpty
          ? 'Your parcel is out for delivery$from'
          : 'Your parcel is out for delivery',
      'DRS' => 'Your parcel is with the courier for delivery',
      'SCF' => place.isNotEmpty
          ? 'Your parcel is ready for self-collection$at'
          : 'Your parcel is ready for self-collection',
      'CPA' => place.isNotEmpty
          ? 'Your parcel has arrived at the collection point$inPlace — we are confirming with you'
          : 'Your parcel has arrived at the collection point — we are confirming with you',
      'SCN' => 'We have sent you a self-collection notice for your parcel',
      'CPI' => place.isNotEmpty
          ? 'Your parcel is ready for pickup at the collection point$inPlace'
          : 'Your parcel is ready for pickup at the collection point',
      'POD' || 'PCC' || 'PFP' || 'PCB' =>
        'Your parcel has been delivered successfully',
      'UND' || 'OVN' => place.isNotEmpty
          ? 'Delivery was unsuccessful$inPlace — we will try again'
          : 'Delivery was unsuccessful — we will try again',
      'RTN' || 'RTS' => 'Your parcel is being returned to the sender',
      'N13' || 'UTL' =>
        'Your parcel is delayed — we are updating the location',
      'N12' || 'N9' =>
        'There is an issue with your parcel — our team is following up',
      'CAN' => 'This order has been cancelled',
      _ => customerLabelOf(key),
    };
  }

  static String friendlyPlace(String? location) {
    final loc = (location ?? '').toUpperCase().trim();
    if (loc.isEmpty) return '';
    return switch (loc) {
      'BKI' || 'KUL' => 'Kota Kinabalu',
      'SDK' => 'Sandakan',
      'TWU' => 'Tawau',
      'SBH325' => 'Kota Kinabalu receiving hub',
      'SBH326' => 'Kota Kinabalu delivery station',
      '805' => 'Kota Kinabalu sorting centre',
      'SDK-ST1' => 'Sandakan station',
      'TWU-ST1' => 'Tawau station',
      _ => loc,
    };
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
      'ARR' || 'SHB' || 'HUB' || 'SCF' || 'CPA' || 'CPI' || 'SCN' => 'SBH325',
      'SRT' || 'MNF' => '805',
      'PKU' || 'ACC' || 'BDE' || 'GWD' => from.isNotEmpty ? from : 'BKI',
      'OFD' || 'DRS' || 'POD' || 'UND' || 'OVN' || 'RTN' =>
        to.isNotEmpty ? to : 'BKI',
      _ => to.isNotEmpty ? to : 'BKI',
    };
  }
}
