/// Device-specific file access, with a separate implementation for web
/// (where `dart:io` doesn't exist).
library;

export 'device_web.dart' if (dart.library.io) 'device_io.dart';
