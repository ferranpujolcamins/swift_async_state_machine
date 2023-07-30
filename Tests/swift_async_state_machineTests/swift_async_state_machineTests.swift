import XCTest

@testable import swift_async_state_machine

enum E {
  case tick
  case change
}

enum TestState {
  case printingRandomNumbers
  case idle
}

extension TestState: State {

  typealias Output = Int
  typealias Events = AnyAsyncSequence<() -> E> // TODO: why we have () -> E instead of E here?

  func receive_events(_ events: AnyAsyncSequence<() -> E>) -> AnyAsyncSequence<
    Either<Output, Self?>
  > {
    print("receive_events")
    switch self {
    case .printingRandomNumbers:
      return events.map {
        switch $0() {
        case .tick:
          return Either.left(Int.random(in: 0...99))
        case .change:
          return Either.right(.idle)
        }
      }.eraseToAnyAsyncSequence()
    case .idle:
      return events.compactMap {
        switch $0() {
        case .tick:
          return nil
        case .change:
          return Either.right(.printingRandomNumbers)
        }
      }.eraseToAnyAsyncSequence()
    }
  }
}

final class swift_async_state_machineTests: XCTestCase {
  func testExample() async throws {
    let initial_state = TestState.idle
    let events = [
      {
        print("first event")
        return E.tick
      },
      { .tick },
      { .tick },
      { .change },
      { .tick },
      { .tick },
      { .tick },
      { .change },
      { 
        print("last event")
        return E.tick },
    ].asyncNotLazy
    let outputs = initial_state.drive(events: events.eraseToAnyAsyncSequence())
    for try await o in outputs {  //WHy this can throw?
      print(o)
    }
  }
}



// a state is a function s: 
// m a -> m (b, StateMachineT m a b)
// a -> m (b, StateMachineT m a b)


// flatMap :: m a -> (a -> m b) -> m b