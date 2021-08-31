import 'dart:async';

typedef Dispatch<Event> = void Function(Event event);
typedef Dispose = void Function();
typedef Reduce<State, Event> = State Function(State state, Event event);
typedef Effect<State, Event> = void Function(State state, State? oldState, Event? event, Dispatch<Event> dispatch);

enum SystemStatus {
  idle, running, disposed
}

class System<State, Event> {

  System({
    required State initialState
  }): state = initialState;

  State state;
  bool _consuming = false;
  SystemStatus status = SystemStatus.idle;
  
  final List<Reduce<State, Event>> _reduces = [];
  final List<Effect<State, Event>> _effects = [];
  final List<Dispose> _disposes = [];
  
  State _reduce(State state, Event event) {
    var _state = state;
    for (final _reduce in _reduces) {
      _state = _reduce(_state, event);
    }
    return _state;
  }
  
  void _effect(State state, State? oldState, Event? event, Dispatch<Event> dispatch) {
    for (final _effect in _effects) {
      _effect(state, oldState, event, dispatch);
    }
  }
  
  void _consume(Event? event) {
    if (status != SystemStatus.running) return;
    if (!_consuming) {
      _consuming = true;
      if (event == null) {
        _effect(state, null, null, dispatch);
      } else {
        final oldState = state;
        state = _reduce(oldState, event);
        _effect(state, oldState, event, dispatch);
      }
      _consuming = false;
    } else {
      Future(() { _consume(event); });
    }
  }
  
  void dispatch(Event event) {
    _consume(event);
  }
  
  void _addReduce(Reduce<State, Event> reduce) => _reduces.add(reduce);

  Dispose _addEffect(Effect<State, Event> effect) {
    _effects.add(effect);
    if (status == SystemStatus.running) {
      effect(state, null, null, dispatch); // replay last state
    }
    return () { _effects.remove(effect); };
  }

  Dispose? add({
    Reduce<State, Event>? reduce,
    Effect<State, Event>? effect,
  }) {
    if (reduce != null) _addReduce(reduce);
    return effect == null ? null : _addEffect(effect);
  }

  Dispose? withContext<Context>({
    required Context Function() createContext,
    Reduce<State, Event>? reduce,
    void Function(Context context, State state, State? oldState, Event? event, Dispatch<Event> dispatch)? effect,
    void Function(Context context)? dispose,
  }) {
    final _context = createContext();
    final Dispose? _disposeEffect = effect == null ? null : _addEffect((state, oldState, event, dispatch) {
      effect(_context, state, oldState, event, dispatch);
    });
    final Dispose? _disposeContext = dispose == null ? null : () { dispose(_context); };
    final Dispose? _disposeEffectAndContext = () {
      if (_disposeContext == null) return _disposeEffect;
      if (_disposeEffect == null) return _disposeContext;
      return () {
        _disposeEffect();
        _disposeContext();
      };
    }();
    if (_disposeEffectAndContext == null) return null;
    _disposes.add(_disposeEffectAndContext);
    return () {
      _disposeEffectAndContext();
      _disposes.remove(_disposeEffectAndContext);
    };
  }
  
  void run() {
    if (status == SystemStatus.idle) {
      status = SystemStatus.running;
      _consume(null);
    };
  }
  
  void dispose() {
    if (status == SystemStatus.disposed) return;
    status = SystemStatus.disposed;
    _disposes
      ..forEach((dispose) => dispose())
      ..clear();
  }

  Dispose? on<ChildEvent>({
    ChildEvent? Function(Event event)? test,
    Reduce<State, ChildEvent>? reduce,
    void Function(State state, ChildEvent event, Dispatch<Event> dispatch)? effect,
  }) {
    final _test = test ?? _safeAs;
    return add(
      reduce: reduce == null ? null : (state, event) {
        final childEvent = _test(event);
        return childEvent == null ? state : reduce(state, childEvent);
      },
      effect: effect == null ? null : (state, oldState, event, dispatch) {
        if (oldState != null && event != null) {
          final childEvent = _test(event);
          if (childEvent != null) effect(state, childEvent, dispatch);
        }
      },
    );
  }

  Dispose onRun({
    required Dispose? Function(State initialState, Dispatch<Event> dispatch) effect,
  }) => withContext<_OnRunContext>(
    createContext: () => _OnRunContext(),
    effect: (context, state, oldState, event, dispatch) {
      if (event == null) {
        context.dispose = effect(state, dispatch);
      }
    },
    dispose: (context) {
      if (context.dispose != null) {
        context.dispose?.call();
        context.dispose = null;
      }
    }
  )!;

  void onDispose({
    required void Function() run
  }) => _disposes.add(run);

}

class _OnRunContext{
  Dispose? dispose;
}


abstract class CounterEvent {}
class CounterEventIncrease implements CounterEvent {}
class CounterEventDecrease implements CounterEvent {}

final counterSystem = System<int, CounterEvent>(initialState: 0)
  ..add(reduce: (state, event) {
    if (event is CounterEventIncrease) {
      return state + 1;
    }
    return state;
  })
  ..add(reduce: (state, event) {
    if (event is CounterEventDecrease) {
      return state - 1;
    }
    return state;
  })
  ..add(effect: (state, oldState, event, dispatch) {
    print('');
    print('Event: $event');
    print('OldState: $oldState');
    print('State: $state');
  })
  ..add(effect: (state, oldState, event, dispatch) async {
    if (event is CounterEventIncrease) {
      await Future<void>.delayed(Duration(seconds: 3));
      dispatch(CounterEventDecrease());
    }
  })
  ..add(effect: (state, oldState, event, dispatch) {
    if (event != null
      && oldState != state
    ) {
      print('Simulate persistence save call with state: $state');
    }
  },)
  ..add(effect: (state, oldState, event, dispatch) {
    if (event == null) { 
      dispatch(CounterEventIncrease());
    }
  });

final counterSystem1 = System<int, CounterEvent>(initialState: 0)
  ..on<CounterEventIncrease>(
    reduce: (state, event) => state + 1,
    effect: (state, event, dispatch) async {
      await Future<void>.delayed(Duration(seconds: 3));
      dispatch(CounterEventDecrease());
    },
  )
  ..on<CounterEventDecrease>(
    reduce: (state, event) => state - 1,
  )
  ..add(effect: (state, oldState, event, dispatch) {
    print('');
    print('Event: $event');
    print('OldState: $oldState');
    print('State: $state');
  })
  // .reactState(
  //   effect: (state, dispatch) {
  //     print('Simulate persistence save call with state: $state');
  //   },
  // )
  ..onRun(effect: (initialState, dispatch) {
    dispatch(CounterEventIncrease());
  },)
  ..onDispose(run: () {
    print('onDispose');
  },);

void main() async {
   
  counterSystem1.run();
    
  await Future<void>.delayed(Duration(seconds: 4));
  
  counterSystem1.dispose();
  
}

R? _safeAs<T, R>(T value) => value is R ? value : null;