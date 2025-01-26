import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalDocumentsScreen extends StatefulWidget {
  @override
  _MedicalDocumentsScreenState createState() => _MedicalDocumentsScreenState();
}

class _MedicalDocumentsScreenState extends State<MedicalDocumentsScreen> {
  List<Map<String, dynamic>> _documents = [];
  String _filterType = 'Todos';
  late Box _documentsBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    await Hive.initFlutter();
    _documentsBox = await Hive.openBox('medical_documents');
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final documents =
        _documentsBox.values.where((doc) => doc['uid'] == user.uid).toList();
    setState(() {
      _documents = documents.map((doc) {
        final file = File(doc['path']);
        return {
          'file': file,
          'title': doc['title'],
          'type': doc['type'],
          'date': DateTime.parse(doc['date']),
        };
      }).toList();
    });
  }

  Future<void> _showDocumentForm({int? index}) async {
    final titleController = TextEditingController(
      text: index != null ? _documents[index]['title'] : '',
    );
    String selectedType = index != null ? _documents[index]['type'] : 'Exame';
    File? selectedFile = index != null ? _documents[index]['file'] : null;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          // title: Text(index != null ? 'Editar' : 'Adicionar'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Título'),
                  ),
                  SizedBox(height: 10),
                  DropdownButton<String>(
                    value: selectedType,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedType = newValue!;
                      });
                    },
                    items: <String>['Exame', 'Receita']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final pickedFile = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          selectedFile = File(pickedFile.path);
                        });
                      }
                    },
                    child: Text('Selecionar'),
                  ),
                  if (selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Image.file(selectedFile!, height: 320),
                    ),
                ],
              );
            },
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && selectedFile != null) {
                    Navigator.pop(context, {
                      'title': titleController.text,
                      'type': selectedType,
                      'file': selectedFile,
                    });
                  }
                },
                child: Text('Salvar'),
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text('Cancelar'),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      User? user = _auth.currentUser;
      if (user == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/medical_documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      final now = DateTime.now();
      final path =
          '${documentsDir.path}/${result['title']}_${result['type']}_${now.toIso8601String()}.png';
      await result['file'].copy(path);

      final documentData = {
        'uid': user.uid,
        'path': path,
        'title': result['title'],
        'type': result['type'],
        'date': now.toIso8601String(),
      };

      if (index != null) {
        await _documents[index]['file'].delete();
        setState(() {
          _documents[index] = {
            'file': File(path),
            'title': result['title'],
            'type': result['type'],
            'date': now,
          };
        });
        await _documentsBox.putAt(index, documentData);
      } else {
        setState(() {
          _documents.add({
            'file': File(path),
            'title': result['title'],
            'type': result['type'],
            'date': now,
          });
        });
        await _documentsBox.add(documentData);
      }
    }
  }

  Future<void> _deleteDocument(int index) async {
    await _documents[index]['file'].delete();
    setState(() {
      _documents.removeAt(index);
    });
    await _documentsBox.deleteAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocuments = _filterType == 'Todos'
        ? _documents
        : _documents.where((doc) => doc['type'] == _filterType).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Exames e Receitas'),
        actions: [
          DropdownButton<String>(
            value: _filterType,
            onChanged: (String? newValue) {
              setState(() {
                _filterType = newValue!;
              });
            },
            items: <String>['Todos', 'Exame', 'Receita']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: filteredDocuments.length,
        itemBuilder: (context, index) {
          final document = filteredDocuments[index];
          final formattedDate =
              DateFormat('dd/MM/yyyy').format(document['date']);
          return GestureDetector(
            onLongPress: () => _showDocumentForm(index: index),
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      child: Image.file(document['file'], fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(document['title'],
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Tipo: ${document['type']}',
                            style: TextStyle(color: Colors.grey)),
                        Text('Incluído em: $formattedDate',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _showDocumentForm(index: index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteDocument(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDocumentForm(),
        child: Icon(Icons.add),
      ),
    );
  }
}
