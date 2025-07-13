import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../constant.dart';

void updateRemoteViews({
  required List<int> remoteUids,
  required List<Widget> remoteViews,
  required RtcEngine engine,
}) {
  log("Updating views for UIDs: $remoteUids");
  remoteViews.clear();
  for (var uid in remoteUids) {
    remoteViews.add(
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(8),
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: uid),
            connection: RtcConnection(channelId: AppConstant.channelName),
          ),
        ),
      ),
    );
  }
}
