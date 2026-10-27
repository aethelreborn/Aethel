import 'package:aethel/features/focus/controllers/focus_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusState.blockError', () {
    test('defaults to null', () {
      expect(const FocusState().blockError, isNull);
    });

    test('copyWith can set and clear blockError without touching the run', () {
      const state = FocusState(remainingSeconds: 90);
      final withError = state.copyWith(blockError: 'needs usage access');

      expect(withError.blockError, 'needs usage access');
      expect(withError.remainingSeconds, 90);
      expect(withError.run, isNull);

      final cleared = withError.copyWith(blockError: null);
      expect(cleared.blockError, isNull);
      expect(cleared.remainingSeconds, 90);
    });

    test('copyWith without blockError keeps the previous value', () {
      const state = FocusState(blockError: 'still broken');
      expect(state.copyWith(remainingSeconds: 1).blockError, 'still broken');
    });
  });
}
