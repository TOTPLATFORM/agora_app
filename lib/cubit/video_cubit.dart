import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_test_app/cubit/video_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VideoCubit extends Cubit<VideoState> {
  VideoCubit() : super(VideoInitialState());

  Future<void> toggleMic(bool isMicOn, RtcEngine engine) async {
    isMicOn = !isMicOn;
    log("${isMicOn ? 'unmute' : 'mute'} mic");
    emit(ToggleMicSuccessState());
    await engine.muteLocalAudioStream(!isMicOn);
  }

  //! toggle camera
  Future<void> toggleCamera(bool isCameraOn, RtcEngine engine) async {
    isCameraOn = !isCameraOn;
    log("${isCameraOn ? 'unmute' : 'mute'} camera");
    emit(ToggleCameraSuccessState());
    await engine.muteLocalVideoStream(!isCameraOn);
    if (isCameraOn) {
      await engine.startPreview();
    }
  }

  //! toggle camera direction (front/back)
  Future<void> toggleCameraDirection(
    bool isFrontCamera,
    RtcEngine engine,
  ) async {
    isFrontCamera = !isFrontCamera;
    log("${isFrontCamera ? 'front' : 'back'} camera");
    emit(ToggleCameraDirectionSuccessState());
    await engine.switchCamera();
  }

  //! toggle speaker
  Future<void> toggleSpeaker(bool isSpeakerOn, RtcEngine engine) async {
    isSpeakerOn = !isSpeakerOn;
    log(isSpeakerOn ? 'speaker' : 'earphone');
    emit(ToggleSpeakerSuccessState());
    await engine.setEnableSpeakerphone(isSpeakerOn);
  }
}
