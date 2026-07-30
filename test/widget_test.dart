import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:iposb/app.dart';

void main() {
  testWidgets('IPOSB app renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: IposbApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(IposbApp), findsOneWidget);
  });
}
