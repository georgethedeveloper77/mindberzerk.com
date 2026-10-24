import 'package:flutter_test/flutter_test.dart';
import 'package:g_network/g_network.dart';

void main() {
  test('parses AppInfo and TCPInfo from a server measurement', () {
    final m = Ndt7Measurement.tryParse(
      '{"AppInfo":{"NumBytes":1250000,"ElapsedTime":1000000},'
      '"TCPInfo":{"MinRTT":24500},"Origin":"server","Test":"upload"}',
    );
    expect(m, isNotNull);
    expect(m!.appBytes, 1250000);
    expect(m.appElapsedUs, 1000000);
    expect(m.minRttUs, 24500);
  });

  test('ignores junk without throwing', () {
    expect(Ndt7Measurement.tryParse('not json'), isNull);
    expect(Ndt7Measurement.tryParse('[1,2]'), isNull);
  });
}
