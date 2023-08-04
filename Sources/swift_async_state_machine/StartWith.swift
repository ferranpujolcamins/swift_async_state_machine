public extension AsyncSequence {
  func startWith(_ initialResult: Element) -> AsyncStartWithSequence<Self> {
    AsyncStartWithSequence(self, initialResult: initialResult)
  }
}

public struct AsyncStartWithSequence<Base: AsyncSequence>: AsyncSequence {
  public typealias Element = Base.Element
  public typealias AsyncIterator = Iterator

  var base: Base
  var initialResult: Element

  public init(
    _ base: Base,
    initialResult: Element
  ) {
    self.base = base
    self.initialResult = initialResult
  }

  public func makeAsyncIterator() -> AsyncIterator {
    Iterator(
      base: self.base.makeAsyncIterator(),
      initialResult: self.initialResult
    )
  }

  public struct Iterator: AsyncIteratorProtocol {
    var base: Base.AsyncIterator
    var initialResult: Element?

    public init(
      base: Base.AsyncIterator,
      initialResult: Element
    ) {
      self.base = base
      self.initialResult = initialResult
    }

    public mutating func next() async rethrows -> Element? {
        if let ir = initialResult {
            initialResult = nil
            return ir
        }
        return try await base.next()
    }
  }
}

extension AsyncStartWithSequence: Sendable where Base: Sendable {}
extension AsyncStartWithSequence.Iterator: Sendable where Base.AsyncIterator: Sendable {}
