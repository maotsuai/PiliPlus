import Foundation

/// A finite recovery lease, separate from iOS's normal background audio mode.
struct PlaybackBackgroundPolicy {
  private(set) var needsTask = false
  private var playing = false
  private var allowed = false
  private var buffering = false
  private var away = false
  private var expired = false
  private var progressStarted: TimeInterval?
  private var lastProgress: TimeInterval?

  var shouldMonitorProgress: Bool {
    away && playing && allowed && !buffering && !expired && !needsTask
  }

  mutating func update(playing: Bool, allowed: Bool, buffering: Bool) {
    self.playing = playing
    self.allowed = allowed
    self.buffering = buffering
    if !playing || !allowed {
      needsTask = false
      resetProgress()
    } else if buffering {
      resetProgress()
      if away && !expired { needsTask = true }
    } else if away && !expired && lastProgress == nil {
      // Includes starting playback from the lock screen.
      needsTask = true
    }
  }

  mutating func leaveForeground() {
    if away { return }
    away = true
    resetProgress()
    if playing && allowed && !expired { needsTask = true }
  }

  mutating func enterForeground() {
    away = false
    expired = false
    needsTask = false
    resetProgress()
  }

  mutating func progress(at now: TimeInterval) {
    guard playing && allowed && !buffering else { return }
    if let last = lastProgress, now - last > 2.5 || now < last {
      progressStarted = nil
    }
    if progressStarted == nil { progressStarted = now }
    lastProgress = now
    if now - progressStarted! >= 2 {
      needsTask = false
      // Only real, sustained playback (or foregrounding) permits another lease.
      expired = false
    }
  }

  mutating func expire() {
    needsTask = false
    expired = true
    resetProgress()
  }

  mutating func suspectStall() {
    guard shouldMonitorProgress else { return }
    needsTask = true
    resetProgress()
  }

  private mutating func resetProgress() {
    progressStarted = nil
    lastProgress = nil
  }
}
