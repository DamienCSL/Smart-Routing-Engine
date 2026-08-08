import 'package:flutter_test/flutter_test.dart';
import 'package:iposb/core/constants/route_paths.dart';
import 'package:iposb/core/router/role_redirect.dart';
import 'package:iposb/core/utils/shipment_qr_payload.dart';
import 'package:iposb/features/shipment/data/mappers/customer_order_mapper.dart';
import 'package:iposb/shared/enums/shipment_status.dart';
import 'package:iposb/shared/enums/user_role.dart';

void main() {
  test('customer role lands on and can access customer routes', () {
    expect(homePathForRole(UserRole.customer), RoutePaths.customerHome);
    expect(
      canAccessRoute(UserRole.customer, RoutePaths.customerCreateShipment),
      isTrue,
    );
    expect(canAccessRoute(UserRole.customer, RoutePaths.notifications), isTrue);
    expect(
      canAccessRoute(UserRole.customer, RoutePaths.hubWorkerHome),
      isFalse,
    );
  });

  test('customer API order preserves addresses, zones, and coordinates', () {
    final shipment = CustomerOrderMapper.fromApi({
      'cnNo': '20001234',
      'status': 'BDE',
      'senderAddress': '1 Jalan Lintas, Kota Kinabalu',
      'address': '2 Jalan Utara, Sandakan',
      'origin': 'BKI',
      'destination': 'SDK',
      'originZone': 'KK-METRO',
      'destinationZone': 'SANDAKAN',
      'originLat': 5.9804,
      'originLng': 116.0735,
      'destinationLat': 5.8402,
      'destinationLng': 118.1179,
      'weight': 2.5,
      'pieces': 2,
      'createdAt': '2026-08-08 09:00:00',
    });

    expect(shipment.trackingNumber, '20001234');
    expect(shipment.originAddress, '1 Jalan Lintas, Kota Kinabalu');
    expect(shipment.destinationAddress, '2 Jalan Utara, Sandakan');
    expect(shipment.originZone, 'KK-METRO');
    expect(shipment.destinationZone, 'SANDAKAN');
    expect(shipment.originLat, 5.9804);
    expect(shipment.destinationLng, 118.1179);
    expect(shipment.status, ShipmentStatus.pending);
  });

  test('shipment QR payload resolves to the same CN for scanning', () {
    const cn = '20001234';
    expect(ShipmentQrPayload.decode(ShipmentQrPayload.encode(cn)), cn);
    expect(ShipmentQrPayload.decode('https://iposb.example/track?cn=$cn'), cn);
    expect(ShipmentQrPayload.decode('{"cnNo":"$cn"}'), cn);
    expect(ShipmentQrPayload.decode('IPOSB:CN:$cn'), cn);
  });
}
