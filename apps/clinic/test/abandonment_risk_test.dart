import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_app/modules/low_vision_hub_page.dart';

/// The abandonment-risk logic is the clinical heart of the Low Vision Hub:
/// a trialing device fit whose copilot signals have gone quiet is the
/// patient about to join the ~29% who abandon within 3 months.
void main() {
  DeviceFitView fit({String status = 'trialing', int signals = 10}) =>
      DeviceFitView(
        id: 'f1',
        patientId: 'p1',
        status: status,
        deviceType: 'handheld magnifier',
        deviceModel: 'Model X',
        recentSignalCount: signals,
      );

  test('a trialing fit with no recent signals is elevated risk', () {
    expect(fit(signals: 0).risk, AbandonmentRisk.elevated);
  });

  test('a trialing fit with sparse signals is on watch', () {
    expect(fit(signals: 2).risk, AbandonmentRisk.watch);
  });

  test('an actively used fit is healthy', () {
    expect(fit(signals: 12).risk, AbandonmentRisk.healthy);
  });

  test('an already-abandoned fit raises no further warning', () {
    expect(fit(status: 'abandoned', signals: 0).risk, AbandonmentRisk.healthy);
  });

  test('fits outside a trial are informational only', () {
    expect(fit(status: 'sustained', signals: 0).risk, AbandonmentRisk.healthy);
  });

  test('the view renders a device description from type and model', () {
    expect(fit().deviceDescription, 'handheld magnifier — Model X');
    expect(
      DeviceFitView(
        id: 'f2',
        patientId: 'p2',
        status: 'trialing',
        deviceType: 'Goz copilot',
        deviceModel: '',
        recentSignalCount: 5,
      ).deviceDescription,
      'Goz copilot',
    );
  });
}
