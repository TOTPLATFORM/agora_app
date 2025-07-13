import 'package:flutter/material.dart';

void showUserApprovalDialog({
  required int remoteUid,
  required BuildContext context,
  required void Function()? accept,
  required void Function()? reject,
}) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text("New Participant Request"),
          content: Text("User $remoteUid wants to join the call"),
          actions: [
            TextButton(onPressed: reject, child: const Text("Reject")),
            TextButton(onPressed: accept, child: const Text("Approve")),
          ],
        ),
  );
}
