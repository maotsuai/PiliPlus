import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:audio_session/audio_session.dart';

class AudioSessionHandler {
  late AudioSession _session;
  bool _shouldResume = false;
  late final Future<void> ready;

  AudioSessionHandler() {
    ready = _initSession();
  }

  Future<bool> setActive(bool active) async {
    await ready;
    return _session.setActive(active);
  }

  void cancelPendingResume() => _shouldResume = false;

  Future<void> _initSession() async {
    _session = await AudioSession.instance;
    await _session.configure(const AudioSessionConfiguration.music());
    _session.interruptionEventStream.listen(_onInterrupted);

    // 耳机拔出暂停
    _session.becomingNoisyEventStream.listen((_) {
      cancelPendingResume();
      videoPlayerServiceHandler?.pause() ?? PlPlayerController.pauseIfExists();
    });
  }

  void _onInterrupted(AudioInterruptionEvent event) {
    final player = PlPlayerController.instance;
    final service = videoPlayerServiceHandler;
    if (event.begin) {
      switch (event.type) {
        case .duck:
          if (player != null && player.playerStatus.isPlaying) {
            player.setVolume(player.volume.value * 0.5, showIndicator: false);
          }
        case .pause:
        case .unknown:
          final isAudioPlaying = service?.isPlaying;
          if (isAudioPlaying != null) {
            if (isAudioPlaying()) {
              _shouldResume = true;
              service?.onPause?.call();
            }
          } else if (player != null &&
              (player.playerStatus.isPlaying || player.wantsToPlay)) {
            _shouldResume = true;
            player.pause(isInterrupt: true);
          }
      }
    } else {
      switch (event.type) {
        case .duck:
          player?.setVolume(player.volume.value * 2, showIndicator: false);
        case .pause:
          final shouldResume = _shouldResume;
          cancelPendingResume();
          if (shouldResume) {
            service?.play() ?? player?.play();
          }
        case .unknown:
          cancelPendingResume();
      }
    }
  }
}
