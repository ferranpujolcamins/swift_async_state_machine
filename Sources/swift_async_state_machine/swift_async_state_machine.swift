import AnyAsyncSequence
import AsyncAlgorithms


protocol State {
  associatedtype Output
  associatedtype Events
  typealias OutputStream = AnyAsyncSequence<Output>

  func receive_events(_ events: Events) -> AnyAsyncSequence<(Output?, Self?)>
  func drive(events: Events) -> OutputStream
}

extension State {
  func drive(events: Events) -> OutputStream {
    let a = receive_events(events)
    let currentStateOutputs: OutputStream = a.map(\.0).compacted().eraseToAnyAsyncSequence()
    let nextState: AnyAsyncSequence<Self> = a.map(\.1).compacted().eraseToAnyAsyncSequence()

    let nextStateOutputs: AnyAsyncSequence<AnyAsyncSequence<Output>> = nextState.map {
      $0.drive(events: events).eraseToAnyAsyncSequence()
    }.eraseToAnyAsyncSequence()

    let x: AnyAsyncSequence<AnyAsyncSequence<Output>> = nextStateOutputs.startWith(
      currentStateOutputs
    ).eraseToAnyAsyncSequence()
    let y: AnyAsyncSequence<Output> = x.flatMap { $0 }.eraseToAnyAsyncSequence()
    // TODO: I think flatmap does not work because it does not interrupt the first sequence when receiving the second one
    return y
  }
}
