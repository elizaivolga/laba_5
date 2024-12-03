import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MaterialApp(home: JournalApp()));
}

class JournalApp extends StatefulWidget {
  @override
  _JournalAppState createState() => _JournalAppState();
}

class _JournalAppState extends State<JournalApp> {
  String journalId = '';
  String? filePath;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPopupStatus();
  }

  Future<void> _checkPopupStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool showPopup = prefs.getBool('showPopup') ?? true;

    if (showPopup) {
      _showInstructionsPopup();
    }
  }

  void _showInstructionsPopup() {
    bool doNotShowAgain = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Инструкция'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Добро пожаловать! Для работы с журналом введите его ID и нажмите "Скачать". После загрузки файла будут доступны функции "Смотреть" и "Удалить".',
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: doNotShowAgain,
                        onChanged: (bool? value) {
                          setState(() {
                            doNotShowAgain = value ?? false;
                          });
                        },
                      ),
                      Text('Больше не показывать'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (doNotShowAgain) {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('showPopup', false);
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/NTV_Journals';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create();
    }
    return path;
  }

  Future<String?> downloadJournal(String id) async {
    final url = 'http://ntv.ifmo.ru/file/journal/$id.pdf';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200 && response.headers['content-type'] == 'application/pdf') {
      final directoryPath = await getAppDirectory();
      final filePath = '$directoryPath/$id.pdf';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      return null;
    }
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void openPdf(String filePath) async {
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл. Установите приложение для просмотра PDF.')),
      );
    }
  }

  void download() async {
    setState(() {
      isLoading = true;
    });
    final result = await downloadJournal(journalId);
    setState(() {
      isLoading = false;
      filePath = result;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл не найден или не является PDF')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл успешно загружен')),
      );
    }
  }

  void deleteFileHandler() async {
    if (filePath != null) {
      await deleteFile(filePath!);
      setState(() {
        filePath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл удалён')),
      );
    }
  }

  void viewFileHandler() {
    if (filePath != null) {
      openPdf(filePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Научно-технический вестник')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Введите ID журнала'),
              onChanged: (value) {
                journalId = value;
              },
            ),
            SizedBox(height: 20),
            if (isLoading) CircularProgressIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(onPressed: download, child: Text('Скачать')),
                if (filePath != null) ...[
                  ElevatedButton(onPressed: viewFileHandler, child: Text('Смотреть')),
                  ElevatedButton(onPressed: deleteFileHandler, child: Text('Удалить')),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
