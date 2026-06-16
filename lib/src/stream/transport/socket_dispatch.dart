/// Platform-conditional dispatch for the default WebSocket channel.
///
/// Re-exports [defaultOpenChannel] from the appropriate dart:io or
/// dart:html backend at compile time. The Dart compiler picks the HTML
/// branch when `dart.library.html` is available (Flutter Web, dart compile
/// js) and the IO branch otherwise (Flutter mobile/desktop, Dart VM).
library;

export 'platform/io_socket.dart'
    if (dart.library.html) 'platform/html_socket.dart';
