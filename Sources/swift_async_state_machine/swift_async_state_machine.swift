import AsyncAlgorithms









public class AnyAsyncSequence<Element>: AsyncSequence {

    // MARK: - Initializers

    /// Create an `AnyAsyncSequence` from an `AsyncSequence` conforming type
    /// - Parameter sequence: The `AnySequence` type you wish to erase
    public init<T: AsyncSequence /*& AnyObject*/>(_ sequence: T) where T.Element == Element {
        makeAsyncIteratorClosure = { AnyAsyncIterator(sequence.makeAsyncIterator()) }
    }

    // MARK: - API

    public class AnyAsyncIterator: AsyncIteratorProtocol {
        private let nextClosure: () async throws -> Element?

        public init<T: AsyncIteratorProtocol>(_ iterator: T) where T.Element == Element {
            var iterator = iterator
            nextClosure = { try await iterator.next() }
        }

        public func next() async throws -> Element? {
            try await nextClosure()
        }
    }

    // MARK: - AsyncSequence

    public typealias Element = Element

    public typealias AsyncIterator = AnyAsyncIterator

    public func makeAsyncIterator() -> AsyncIterator {
        AnyAsyncIterator(makeAsyncIteratorClosure())
    }

    private let makeAsyncIteratorClosure: () -> AsyncIterator

}

public extension AsyncSequence /*where Self: AnyObject*/ {

    /// Create a type erased version of this sequence
    /// - Returns: The sequence, wrapped in an `AnyAsyncSequence`
    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(self)
    }

}


extension Sequence {
  /// An asynchronous sequence containing the same elements as this sequence,
  /// but on which operations, such as `map` and `filter`, are
  /// implemented asynchronously.
  @inlinable
  public var asyncNotLazy: AsyncSyncNotLazySequence<Self> {
    AsyncSyncNotLazySequence(self)
  }
}

public final class AsyncSyncNotLazySequence<Base: Sequence>: AsyncSequence {
  public typealias Element = Base.Element
  

  public class Iterator: AsyncIteratorProtocol {
    @usableFromInline
    var iterator: Base.Iterator?
    
    @usableFromInline
    init(_ iterator: Base.Iterator) {
      self.iterator = iterator
    }
    
    @inlinable
    public func next() async -> Base.Element? {
      if !Task.isCancelled, let value = iterator?.next() {
        return value
      } else {
        iterator = nil
        return nil
      }
    }
  }
  
  @usableFromInline
  let base: Base
  
  @usableFromInline
  init(_ base: Base) {
    self.base = base
  }
  
  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(base.makeIterator())
  }
}

extension AsyncSyncNotLazySequence: Sendable where Base: Sendable { }










public enum Either<A, B> {
    case left(A)
    case right(B)

    public func getLeft() -> A? {
        if case let .left(a) = self {
            return a
        }
        return nil
    }
}

extension Task {
    func asAsyncSequence() -> some AsyncSequence {
        AsyncStream<Success> {
            do {
                return try await self.value
            } catch {
                return nil
            }
        }
    }
}

extension AsyncSequence {
    @inlinable
    public func extend<Tail: AsyncSequence>(_ f: @escaping @Sendable (Element) -> Tail) -> ExtendSequence<Self, Tail> where Element == Tail.Element {
        ExtendSequence(self, f)
    }

    @inlinable
    public func extendHeterogeneously<Tail: AsyncSequence>(_ f: @escaping @Sendable (Element) -> Tail) -> some AsyncSequence {
        self.map(Either<Element, Tail.Element>.left).extend {
            f($0.getLeft()!).map(Either<Element, Tail.Element>.right)
        } as ExtendSequence<AsyncMapSequence<Self, Either<Element, Tail.Element>>, AsyncMapSequence<Tail, Either<Element, Tail.Element>>>
    }
}

@frozen
public struct ExtendSequence<Base: AsyncSequence, Tail: AsyncSequence> where Base.Element == Tail.Element {
  @usableFromInline
  let base: Base
  
  @usableFromInline
  let f: @Sendable (Base.Element) -> Tail
  
  @usableFromInline
  init(_ base: Base, _ f: @escaping @Sendable (Base.Element) -> Tail)  {
    self.base = base
    self.f = f
  }
}

extension ExtendSequence: AsyncSequence {
  public typealias Element = Tail.Element
  
  /// The iterator for a `ExtendSequence` instance.
  @frozen
  public struct Iterator: AsyncIteratorProtocol {
    @usableFromInline
    var base: Base.AsyncIterator?

    @usableFromInline
    var lastValue: Base.Element?
    
    @usableFromInline
    var tail: Tail.AsyncIterator?

    @usableFromInline
    let f: (Base.Element) -> Tail
    
    @usableFromInline
    init(_ base: Base.AsyncIterator, _ f: @escaping (Base.Element) -> Tail) {
      self.base = base
      self.lastValue = nil
      self.tail = nil
      self.f = f
    }
    
    @inlinable
    public mutating func next() async rethrows -> Element? {
      do {
        if let value = try await base?.next() {
          lastValue = value
          return value
        } else {
          base = nil
          if let lastValue = lastValue {
              tail = f(lastValue).makeAsyncIterator()
          }
        }
        return try await tail?.next()
      } catch {
        base = nil
        tail = nil
        throw error
      }
    }
  }
  
  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(base.makeAsyncIterator(), f)
  }
}

extension ExtendSequence: Sendable where Base: Sendable, Tail: Sendable { }

protocol State {
    associatedtype Output
    associatedtype Events
    typealias OutputStream = AnyAsyncSequence<Output>

    func receive_events(_ events: Events) -> AnyAsyncSequence<Either<Output, Self?>>

    func drive(events: Events) -> OutputStream
}

extension State {
    func drive(events: Events) -> OutputStream {
        receive_events(events).flatMap { (arg: Either<Output, Self?>) -> AnyAsyncSequence<Output> in // TODO: build a version fo this that uses an enum internally to avoid heap alloc
            switch arg {
                case .left(let output):
                    return [output].asyncNotLazy.eraseToAnyAsyncSequence()
                case .right(let newState?): 
                    print("newState: \(newState)")
                    return newState.drive(events: events).eraseToAnyAsyncSequence()
                
                case .right(nil): return [].asyncNotLazy.eraseToAnyAsyncSequence()
            }
        }.eraseToAnyAsyncSequence()
    }
}