import Cocoa
import SwiftUI
import Combine

class MarkdownDocument: NSDocument, ObservableObject {
  var cancellables = Set<AnyCancellable>()
  let parser = MarkdownParser()

  var markupUpdate = CurrentValueSubject<String, Never>("")
  var sourceUpdate = CurrentValueSubject<String, Never>("")

  var path: String {
    return fileURL?.path ?? ""
  }

  override init() {
    super.init()
  }

  override class var autosavesInPlace: Bool {
    return true
  }

  override func makeWindowControllers() {
    let contentView = RenderView(.init(document: self))

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    window.center()
    window.contentView = NSHostingView(rootView: contentView)
    window.setFrameAutosaveName(path)
    let windowController = WindowController(window: window)
    self.addWindowController(windowController)
  }

  override func read(from url: URL, ofType typeName: String) throws {
    markupUpdate.send(parser.parse(path))
    addToWatchedPaths()
    listenToChanges()
  }

  deinit {
    removeFromWatchedPaths()
  }

  private func listenToChanges() {
    FileWatcher.shared.fileEvent
      .filter { eventPath in
        self.path == eventPath
      }
      .map { path in
        return try? String(contentsOfFile: path, encoding: .utf8)
      }
      .compactMap { $0 }
      .sink {
        self.sourceUpdate.send($0)
      }
      .store(in: &cancellables)


    sourceUpdate
      .map { [unowned self] markdown in
        return self.parser.parse(markdown)
      }
      .sink {
        self.markupUpdate.send($0)
      }
      .store(in: &cancellables)
  }

  private func addToWatchedPaths() {
    FileWatcher.shared.pathsToWatch.append(path)
  }

  private func removeFromWatchedPaths() {
    let watcher = FileWatcher.shared

    if let index = watcher.pathsToWatch.firstIndex(of: path) {
      watcher.pathsToWatch.remove(at: index)
    }
  }
}
