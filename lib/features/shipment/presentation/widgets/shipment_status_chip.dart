import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../shared/enums/shipment_status.dart';

class ShipmentStatusChip extends StatelessWidget {
  const ShipmentStatusChip({
    super.key,
    required this.status,
    this.labelOverride,
  });

  final ShipmentStatus status;
  final String? labelOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _colors(scheme);
    final label = labelOverride ?? _labelFor(status);

    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  static String _labelFor(ShipmentStatus status) {
    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      return switch (status) {
        ShipmentStatus.pending => 'Pending Pickup',
        ShipmentStatus.assigned => 'Courier Assigned',
        ShipmentStatus.pickedUp => 'Collected',
        ShipmentStatus.inTransit => 'In Transit',
        ShipmentStatus.outForDelivery => 'Out for Delivery',
        ShipmentStatus.delivered => 'Delivered',
        ShipmentStatus.cancelled => 'Cancelled',
        ShipmentStatus.failed => 'Delivery Delayed',
        _ => status.label,
      };
    }
    return status.label;
  }

  (Color, Color) _colors(ColorScheme scheme) {
    return switch (status) {
      ShipmentStatus.pending => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      ShipmentStatus.delivered => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      ShipmentStatus.cancelled || ShipmentStatus.failed => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
  }
}
