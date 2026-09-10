import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies a picked image into the app's own documents directory and
/// returns the local path to store — replaces what used to be a multipart
/// upload to the server (see the old `POST /users/me/avatar`).
Future<String> saveAvatarFile(String sourcePath) async {
  final dir = await getApplicationDocumentsDirectory();
  final avatarsDir = Directory(p.join(dir.path, 'avatars'));
  if (!await avatarsDir.exists()) await avatarsDir.create(recursive: true);

  final ext = p.extension(sourcePath);
  final destPath = p.join(avatarsDir.path, 'avatar$ext');

  // Overwrite any previous avatar rather than accumulating files forever.
  final dest = File(destPath);
  if (await dest.exists()) await dest.delete();
  await File(sourcePath).copy(destPath);

  return destPath;
}
