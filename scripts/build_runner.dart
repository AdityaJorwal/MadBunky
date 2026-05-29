import 'dart:io';

void main() async {
  stdout.writeln('Starting build...');
  final logFile = File('build_log.txt');
  final sink = logFile.openWrite();

  try {
    // Try running flutter build
    stdout.writeln('Launching flutter build apk --release --verbose...');
    final process = await Process.start(
        'flutter.bat', ['build', 'apk', '--release', '--verbose'],
        runInShell: true, workingDirectory: Directory.current.path);

    process.stdout.listen((data) {
      sink.add(data);
      stdout.add(data);
    });

    process.stderr.listen((data) {
      sink.add(data);
      stderr.add(data);
    });

    final exitCode = await process.exitCode;
    sink.writeln('\nBuild finished with exit code $exitCode');
    stdout.writeln('Build finished with exit code $exitCode');
  } catch (e) {
    sink.writeln('Error launching process: $e');
    stdout.writeln('Error launching process: $e');
  } finally {
    await sink.close();
  }
}
