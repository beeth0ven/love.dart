

typedef Reduce<State, Event> = void Function(State state, Event event);
class Reducer<State, Event> {
  const Reducer(this.reduce);
  final Reduce<State, Event> reduce; 
}

typedef Dispatch<Event> = void Function(Event event);
class Dispatcher<Event> {
  const Dispatcher(this.dispatch);
  final Dispatch<Event> dispatch;
}

typedef Effect<State, Event> = void Function(State state, State? oldState, Event? event, Dispatch<Event> dispatch);
class Effector<State, Event> {
  const Effector(this.effect);
  final Effect<State, Event> effect;
}

typedef Dispose = void Function();
class Disposer {
  const Disposer(this.dispose);
  final Dispose dispose;

  static const Disposer empty = Disposer(_emptyFunc);
}

void _emptyFunc() {}

final reducer = Reducer<String, String>((state, event) => event);
