/// Shipment lifecycle statuses stored in `shipments.status`.
enum ShipmentStatus {
  pending('pending', 'Pending Assignment'),
  assigned('assigned', 'Assigned'),
  pickupScheduled('pickup_scheduled', 'Pickup Scheduled'),
  pickedUp('picked_up', 'Picked Up'),
  atOriginDropPoint('at_origin_drop_point', 'At Origin Drop Point'),
  atOriginHub('at_origin_hub', 'At Origin Hub'),
  sorting('sorting', 'Sorting'),
  inTransit('in_transit', 'In Transit'),
  atDestinationHub('at_destination_hub', 'At Destination Hub'),
  atDestinationDropPoint('at_destination_drop_point', 'At Destination Drop Point'),
  outForDelivery('out_for_delivery', 'Out for Delivery'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled'),
  failed('failed', 'Failed');

  const ShipmentStatus(this.value, this.label);

  final String value;
  final String label;

  static ShipmentStatus fromValue(String value) {
    return ShipmentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ShipmentStatus.pending,
    );
  }
}
