// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  try {
    var src = File('assets/icon/mb.png');
    var dest =
        File('android/app/src/main/res/drawable/ic_launcher_foreground.png');

    if (!await src.exists()) {
      print('Source does not exist');
      exit(1);
    }

    if (!await dest.parent.exists()) {
      await dest.parent.create(recursive: true);
    }

    await src.copy(dest.path);
    print('Copied successfully to ${dest.path}');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
