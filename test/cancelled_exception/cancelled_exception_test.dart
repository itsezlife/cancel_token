import 'package:cancel_token/cancel_token.dart';
import 'package:test/test.dart';

void main() {
  group('CancelledException', () {
    test('toString without reason', () {
      expect(const CancelledException().toString(), 'CancelledException');
    });

    test('toString with reason', () {
      expect(
        const CancelledException('gone').toString(),
        'CancelledException: gone',
      );
    });
  });
}
