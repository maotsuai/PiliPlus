import AVFoundation
import Flutter
import UIKit

/// Owns exactly one UIKit background task. All entry points run on the main queue.
final class PlaybackBackgroundTask {
  private let channel: FlutterMethodChannel
  private var policy = PlaybackBackgroundPolicy()
  private var task: UIBackgroundTaskIdentifier = .invalid
  private var generation = 0
  private var deadline: Timer?
  private var progressDeadline: Timer?
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.example.piliplus/playback_background",
      binaryMessenger: messenger
    )
    if UIApplication.shared.applicationState != .active {
      policy.leaveForeground()
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "update":
        guard let state = call.arguments as? [String: Bool],
          let playing = state["playing"],
          let allowed = state["allowed"],
          let buffering = state["buffering"]
        else {
          result(FlutterError(code: "invalid_state", message: "Missing playback state", details: nil))
          return
        }
        self.policy.update(playing: playing, allowed: allowed, buffering: buffering)
      case "progress":
        self.policy.progress(at: ProcessInfo.processInfo.systemUptime)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      self.applyPolicy()
      if call.method == "progress" { self.monitorProgress(reset: true) }
      result(nil)
    }
    for name in [UIApplication.willResignActiveNotification, UIScene.willDeactivateNotification] {
      observe(name) { [weak self] _ in
        self?.policy.leaveForeground()
        self?.applyPolicy()
      }
    }
    for name in [UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification] {
      observe(name) { [weak self] _ in
        self?.policy.enterForeground()
        self?.applyPolicy()
      }
    }
    observe(AVAudioSession.interruptionNotification) { [weak self] notification in
      guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        type == AVAudioSession.InterruptionType.began.rawValue
      else { return }
      // Release immediately, even if Dart has not received the interruption yet.
      self?.policy.update(playing: false, allowed: false, buffering: false)
      self?.applyPolicy()
    }
  }

  private func observe(_ name: Notification.Name, handler: @escaping (Notification) -> Void) {
    observers.append(NotificationCenter.default.addObserver(
      forName: name, object: nil, queue: .main, using: handler
    ))
  }

  private func applyPolicy() {
    monitorProgress()
    guard policy.needsTask else { endTask(); return }
    guard task == .invalid else { return }
    generation += 1
    let current = generation
    let granted = UIApplication.shared.beginBackgroundTask(withName: "Playback recovery") { [weak self] in
      self?.expire(generation: current)
    }
    // Expiration can arrive synchronously if UIKit cannot grant execution time.
    guard current == generation && policy.needsTask else {
      if granted != .invalid { UIApplication.shared.endBackgroundTask(granted) }
      return
    }
    task = granted
    guard task != .invalid else { policy.expire(); return }
    // UIKit may grant less time; its expiration handler always takes priority.
    // Never chain tasks or renew the deadline merely because buffering repeats.
    deadline = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in
      self?.expire(generation: current)
    }
  }

  private func monitorProgress(reset: Bool = false) {
    guard policy.shouldMonitorProgress else {
      progressDeadline?.invalidate()
      progressDeadline = nil
      return
    }
    if !reset && progressDeadline != nil { return }
    progressDeadline?.invalidate()
    // A native deadline bridges silent stalls before the Dart retry fires.
    // Normal progress cancels it, so it does not wake periodically while playing.
    progressDeadline = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
      self?.progressDeadline = nil
      self?.policy.suspectStall()
      self?.applyPolicy()
    }
  }

  private func expire(generation current: Int) {
    guard current == generation else { return }
    policy.expire()
    progressDeadline?.invalidate()
    progressDeadline = nil
    endTask()
  }

  private func endTask() {
    deadline?.invalidate()
    deadline = nil
    generation += 1
    let ending = task
    task = .invalid
    if ending != .invalid { UIApplication.shared.endBackgroundTask(ending) }
  }

  deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    deadline?.invalidate()
    if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
    progressDeadline?.invalidate()
  }
}
