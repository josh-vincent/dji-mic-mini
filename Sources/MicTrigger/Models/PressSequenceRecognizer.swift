import Foundation

final class PressSequenceRecognizer {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var pendingCount = 0
    private var pendingWorkItem: DispatchWorkItem?
    var onSequence: ((Int) -> Void)?

    init(interval: TimeInterval = 0.42, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    func registerPress() {
        pendingWorkItem?.cancel()
        pendingCount += 1

        if pendingCount >= 3 {
            finish()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            self?.finish()
        }
        pendingWorkItem = item
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    func flush() {
        pendingWorkItem?.cancel()
        finish()
    }

    private func finish() {
        guard pendingCount > 0 else { return }
        let count = pendingCount
        pendingCount = 0
        pendingWorkItem = nil
        onSequence?(count)
    }
}
