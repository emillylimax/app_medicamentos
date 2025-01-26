import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class MedicalDocumentsScreen extends StatefulWidget {
  @override
  _MedicalDocumentsScreenState createState() => _MedicalDocumentsScreenState();
}

class _MedicalDocumentsScreenState extends State<MedicalDocumentsScreen> {
  List<File> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final directory = await getApplicationDocumentsDirectory();
    final documentsDir = Directory('${directory.path}/medical_documents');
    if (await documentsDir.exists()) {
      final files = documentsDir.listSync().whereType<File>().toList();
      setState(() {
        _documents = files;
      });
    }
  }

  Future<void> _pickDocument() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/medical_documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      final path =
          '${documentsDir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(pickedFile.path);
      await file.copy(path);
      setState(() {
        _documents.add(File(path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exames e Receitas')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          return Image.file(_documents[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDocument,
        child: Icon(Icons.add),
      ),
    );
  }
}
