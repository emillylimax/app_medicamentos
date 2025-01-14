import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EditarPerfilScreen extends StatefulWidget {
  @override
  _EditarPerfilScreenState createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nomeController.text = userDoc['name'] ?? '';
          _dobController.text = userDoc['dob'] ?? '';
          _emailController.text = user.email ?? '';
          _loadImage(user.uid);
        });
      }
    }
  }

  Future<void> _loadImage(String uid) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/profile_pictures/$uid.png';
    final file = File(path);
    if (await file.exists()) {
      setState(() {
        _imageFile = file;
      });
    }
  }

  Future<void> _editarPerfil() async {
    User? user = _auth.currentUser;

    if (user != null && _nomeController.text.isNotEmpty) {
      try {
        if (_imageFile != null) {
          final directory = await getApplicationDocumentsDirectory();
          final profilePicturesDir =
              Directory('${directory.path}/profile_pictures');
          if (!await profilePicturesDir.exists()) {
            await profilePicturesDir.create(recursive: true);
          }
          final path = '${profilePicturesDir.path}/${user.uid}.png';
          await _imageFile!.copy(path);
        }

        await user.updateDisplayName(_nomeController.text);
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nomeController.text,
          'dob': _dobController.text,
          'email': _emailController.text,
        });
        await user.reload();
        user = _auth.currentUser;

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Perfil atualizado com sucesso!')));

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar perfil: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nome inválido ou não autenticado.')));
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _deleteAccount() async {
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).delete();

        await user.delete();

        Navigator.pushReplacementNamed(context, '/');
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir conta: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : NetworkImage(_auth.currentUser?.photoURL ??
                        'https://via.placeholder.com/250') as ImageProvider,
                child: _imageFile == null
                    ? Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            TextField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Nome')),
            TextField(
                controller: _dobController,
                decoration: InputDecoration(labelText: 'Data de Nascimento')),
            TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'E-mail'),
                enabled: false),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _editarPerfil,
              child: Text('Salvar Alterações'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _deleteAccount,
              child: Text('Excluir Conta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 227, 105, 96),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
