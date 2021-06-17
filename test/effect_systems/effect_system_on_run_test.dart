
import 'package:test/test.dart';
import 'package:love/love.dart';

import '../test_utils/test_utils.dart';

void main() {

  test('EffectSystem.onRun', () async {

    int invoked = 0;
    List<String> stateParameters = [];
    
    final it = await testEffectSystem<String, String>(
      system: createTestEffectSystem(initialState: 'a')
        .onRun(
          effect: (initialState, dispatch) {
            dispatch('b');
            delayed(10, () => dispatch('c'));
            stateParameters.add(initialState);
            invoked += 1;
          },
        ),
      events: (dispatch, dispose) => [
        dispatch(20, 'd'),
        dispatch(30, 'e'),
        dispose(40),
        dispatch(50, 'f'),
      ],
      awaitMilliseconds: 60,
    );

    expect(it.events, [
      null,
      'b',
      'c',
      'd',
      'e',
    ]);

    expect(it.states, [
      'a',
      'a|b',
      'a|b|c',
      'a|b|c|d',
      'a|b|c|d|e',
    ]);

    expect(it.oldStates, [
      null,
      'a',
      'a|b',
      'a|b|c',
      'a|b|c|d',
    ]);

    expect(it.isDisposed, true);

    expect(stateParameters, [
      'a'
    ]);

    expect(invoked, 1);

  });
}