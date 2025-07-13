import 'package:equatable/equatable.dart';

sealed class VideoState extends Equatable {}

final class VideoInitialState extends VideoState {
  @override
  List<Object?> get props => [];
}

final class ToggleMicSuccessState extends VideoState {
  @override
  List<Object?> get props => [];
}

final class ToggleCameraSuccessState extends VideoState {
  @override
  List<Object?> get props => [];
}

final class ToggleCameraDirectionSuccessState extends VideoState {
  @override
  List<Object?> get props => [];
}

final class ToggleSpeakerSuccessState extends VideoState {
  @override
  List<Object?> get props => [];
}
