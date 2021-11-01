/// Describe how state update when event come
typedef Reduce<State, Event> = State Function(State state, Event event);
