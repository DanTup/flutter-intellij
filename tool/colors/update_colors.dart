// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  await downloadDartFiles();
}

void downloadDartFiles() async {
  File materialFile = File('tool/colors/flutter/colors_material.dart');
  File cupertinoFile = File('tool/colors/flutter/colors_cupertino.dart');
  // download material/colors.dart and cupertino/colors.dart
  await Future.wait([
    downloadFile(
        'https://raw.githubusercontent.com/flutter/flutter/'
        'master/packages/flutter/lib/src/material/colors.dart',
        materialFile),
    downloadFile(
        'https://raw.githubusercontent.com/flutter/flutter/'
        'master/packages/flutter/lib/src/cupertino/colors.dart',
        cupertinoFile)
  ]);

  // parse into metadata
  List<String> materialColors = extractColorNames(materialFile);
  List<String> cupertinoColors = extractColorNames(cupertinoFile);

  // generate .properties files
  generateDart(materialColors, 'colors_material.dart', 'Colors');
  generateDart(cupertinoColors, 'colors_cupertino.dart', 'CupertinoColors');
}

Future<void> downloadFile(String url, File file) async {
  RegExp imports = new RegExp(r'(?:^import.*;\n{1,})+', multiLine: true);
  HttpClient client = new HttpClient();
  try {
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    List<String> data = await utf8.decoder.bind(response).toList();
    String contents =
        data.join('').replaceFirst(imports, "import '../stubs.dart';\n\n");

    file.writeAsStringSync(
        '/// This file was downloaded by update_colors.dart.\n\n$contents');
  } finally {
    client.close();
  }
}

// The pattern below is meant to match lines like:
//   'static const Color black45 = Color(0x73000000);'
//   'static const MaterialColor cyan = MaterialColor('
final RegExp regexp = new RegExp(r'static const \w*Color (\S+) = \w*Color\(');

List<String> extractColorNames(File file) {
  String data = file.readAsStringSync();
  return regexp.allMatches(data).map((Match match) => match.group(1)).toList();
}

void generateDart(List<String> colors, String filename, String className) {
  StringBuffer buf = StringBuffer();
  buf.writeln('''
// Generated file - do not edit.

import '../stubs.dart';
import '../flutter/${filename}';

final Map<String, Color> colors = <String, Color>{''');

  for (String colorName in colors) {
    buf.writeln('  "${colorName}": ${className}.${colorName},');
  }

  buf.writeln('};');

  new File('tool/colors/generated/$filename').writeAsStringSync(buf.toString());

  print('wrote tool/colors/generated/$filename');
}
