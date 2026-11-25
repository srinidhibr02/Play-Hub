import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet with [text]. If sharing is not available,
/// the text is copied instead and the person is told.
Future<void> shareText(
  BuildContext context,
  String text, {
  String? subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Copied. Paste it in a chat to share.')),
      );
  }
}
