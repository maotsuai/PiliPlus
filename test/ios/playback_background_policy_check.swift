import Foundation

// Run with swiftc and PlaybackBackgroundPolicy.swift; no iOS simulator is needed.
@main
struct PlaybackBackgroundPolicyChecks {
  static func main() {
    check("background playback must be explicitly allowed") {
      var policy = PlaybackBackgroundPolicy()
      policy.update(playing: true, allowed: false, buffering: true)
      policy.leaveForeground()
      precondition(!policy.needsTask)
    }
    check("lock-screen transition reserves a recovery window") {
      var policy = playingPolicy()
      policy.leaveForeground()
      precondition(policy.needsTask)
    }
    check("buffering in foreground does not consume a background task") {
      var policy = playingPolicy()
      policy.update(playing: true, allowed: true, buffering: true)
      precondition(!policy.needsTask)
      policy.leaveForeground()
      precondition(policy.needsTask)
    }
    check("only sustained playback releases the task") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.progress(at: 0)
      policy.progress(at: 1)
      precondition(policy.needsTask)
      policy.progress(at: 2)
      precondition(!policy.needsTask)
      policy.update(playing: true, allowed: true, buffering: true)
      precondition(policy.needsTask)
    }
    check("a gap in progress is not sustained recovery") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.progress(at: 0)
      policy.progress(at: 10)
      precondition(policy.needsTask)
      policy.progress(at: 11)
      precondition(policy.needsTask)
      policy.progress(at: 12)
      precondition(!policy.needsTask)
    }
    check("pause or interruption releases the task immediately") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.update(playing: false, allowed: true, buffering: true)
      precondition(!policy.needsTask)
      policy.progress(at: 5)
      precondition(!policy.needsTask)
    }
    check("expiration cannot chain background tasks") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.expire()
      for _ in 0..<10 {
        policy.update(playing: true, allowed: true, buffering: true)
        policy.leaveForeground()
        precondition(!policy.needsTask)
      }
      policy.update(playing: true, allowed: true, buffering: false)
      precondition(!policy.needsTask)
    }
    check("sustained recovery permits protection for a later stall") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.expire()
      policy.progress(at: 0)
      policy.progress(at: 1)
      policy.progress(at: 2)
      policy.update(playing: true, allowed: true, buffering: true)
      precondition(policy.needsTask)
    }
    check("foregrounding releases the task and resets expiration") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.expire()
      policy.enterForeground()
      precondition(!policy.needsTask)
      policy.leaveForeground()
      precondition(policy.needsTask)
    }
    check("disabling background playback releases an existing task") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.update(playing: true, allowed: false, buffering: false)
      precondition(!policy.needsTask)
    }
    check("native progress deadline protects a silent stall") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.progress(at: 0)
      policy.progress(at: 1)
      policy.progress(at: 2)
      precondition(policy.shouldMonitorProgress)
      policy.suspectStall()
      precondition(policy.needsTask)
      precondition(!policy.shouldMonitorProgress)
    }
    check("native deadlines cannot restart an expired or paused task") {
      var policy = playingPolicy()
      policy.leaveForeground()
      policy.expire()
      policy.suspectStall()
      precondition(!policy.needsTask)
      policy.enterForeground()
      policy.leaveForeground()
      policy.update(playing: false, allowed: true, buffering: false)
      policy.suspectStall()
      precondition(!policy.needsTask)
    }
    print("All 12 background playback policy checks passed.")
  }

  static func playingPolicy() -> PlaybackBackgroundPolicy {
    var policy = PlaybackBackgroundPolicy()
    policy.update(playing: true, allowed: true, buffering: false)
    return policy
  }

  static func check(_ name: String, _ body: () -> Void) {
    body()
    print("PASS: \(name)")
  }
}
