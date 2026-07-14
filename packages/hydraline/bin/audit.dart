import 'dart:io';

import 'package:hydraline/hydraline.dart';

Future<void> main(List<String> args) async {
  exitCode = await runAuditCli(args);
}
