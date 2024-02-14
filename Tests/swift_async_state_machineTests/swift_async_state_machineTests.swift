import AnyAsyncSequence
import AsyncAlgorithms
import XCTest


@testable import swift_async_state_machine

enum Events {
  case tick
  case change
}

enum TestState {
  case foreground
  case background
}

extension TestState: State {
  typealias Output = Int

  func receive_events(_ events: AnyAsyncSequence<Events>) -> AnyAsyncSequence<(Output?, Self?)> {
    print("receive_events")
    switch self {
    case .foreground:
      return events.map {
        switch $0 {
        case .tick:
          return (Int.random(in: 0...99), nil)
        case .change:
          return (nil, .background)
        }
      }.eraseToAnyAsyncSequence()
    case .background:
      return events.chunked(by: AsyncTimerSequence.repeating(every: .seconds(3))).flatMap {$0.async}.map {
        switch $0 {
        case .tick:
          return (Int.random(in: -99...0), nil)
        case .change:
          return (nil, .foreground)
        }
      }.eraseToAnyAsyncSequence()
    }
  }
}


final class swift_async_state_machineTests: XCTestCase {

  func testExample() async throws {
      let initial_state = TestState.background
      var events = [
          Events.tick,
          .tick,
          .tick,
          .tick,
          .tick,
          .tick,
          .tick,
          .tick,
          .change
      ]

      let t = AsyncTimerSequence(interval: .seconds(0.1), clock: .continuous)
        .prefix(events.count)
        .map { events.popLast() }
        .eraseToAnyAsyncSequence()

      let outputs = initial_state.drive(events: t)
      for try await o in outputs {  //WHy this can throw?
         print("\(Date()): \(o)")
      }
  }
}

// a state is a function s:


// m a -> m (b, StateMachineT m a b)
// a -> m (b, StateMachineT m a b)

// flatMap :: m a -> (a -> m b) -> m b
