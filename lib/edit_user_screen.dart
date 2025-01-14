import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
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
  late Box _userBox;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _carregarDadosUsuario();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _syncLocalDataWithFirebase();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeHive() async {
    _userBox = await Hive.openBox('user');
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
      final userData = {
        'name': _nomeController.text,
        'dob': _dobController.text,
        'email': _emailController.text,
      };

      if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
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
          await _firestore.collection('users').doc(user.uid).update(userData);
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
        await _salvarDadosLocalmente(userData);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sem conexão. Dados salvos localmente.')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nome inválido ou não autenticado.')));
    }
  }

  Future<void> _salvarDadosLocalmente(Map<String, dynamic> userData) async {
    await _userBox.put('userData', userData);
  }

  Future<void> _syncLocalDataWithFirebase() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final localData = _userBox.get('userData');
    if (localData != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update(localData);
        await _userBox.delete('userData');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dados sincronizados com sucesso!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao sincronizar dados: $e')));
      }
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

  Future<void> _confirmDeleteAccount() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Exclusão'),
          content: Text(
              'Tem certeza de que deseja excluir sua conta? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showReauthenticationDialog();
              },
              child: Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReauthenticationDialog() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reautenticação Necessária'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'E-mail'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Senha'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _reauthenticateAndDelete(
                    emailController.text, passwordController.text);
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reauthenticateAndDelete(String email, String password) async {
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        AuthCredential credential =
            EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(credential);

        QuerySnapshot medicamentosSnapshot = await _firestore
            .collection('medicamentos')
            .where('uid', isEqualTo: user.uid)
            .get();

        for (DocumentSnapshot doc in medicamentosSnapshot.docs) {
          await doc.reference.delete();
        }

        // Excluir dados do usuário
        await _firestore.collection('users').doc(user.uid).delete();

        // Excluir conta do usuário
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
              onPressed: _confirmDeleteAccount,
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
