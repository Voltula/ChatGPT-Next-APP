import 'dart:io';
import 'dart:math';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;

final rand = Random();
int portMin = 1024;
int portMax = 65535;
WebUri serverAddr = WebUri("http://localhost:3000");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 隐藏所有系统UI（状态栏/导航栏）
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // 初始化Web服务器
  var appDocDir = await getApplicationSupportDirectory();
  print("Server root: ${appDocDir.path}");
  
  var webDir = Directory(path.join(appDocDir.path, "web"));
  if (!webDir.existsSync()) {
    print("Unzipping web assets...");
    var data = await rootBundle.load("assets/web.zip");
    final archive = ZipDecoder().decodeBuffer(InputStream(data.buffer.asUint8List()));
    await extractArchiveToDisk(archive, appDocDir.path);
  }

  var pipe = const Pipeline();
  if (kDebugMode) pipe.addMiddleware(logRequests());
  
  var handler = pipe.addHandler(
      createStaticHandler(webDir.path, defaultDocument: 'index.html'));

  // 启动服务器
  late HttpServer server;
  for (int i = 0; i < 5; i++) {
    try {
      server = await shelf_io.serve(handler, serverAddr.host, serverAddr.port);
      break;
    } on SocketException {
      int port = portMin + rand.nextInt(portMax - portMin);
      serverAddr = WebUri("http://localhost:$port");
    }
  }
  
  server.autoCompress = true;
  print('Serving at http://${server.address.host}:${server.port}');
  
  // 创建空白UI保持后台运行
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(),
    ),
  ));
}
