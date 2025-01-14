import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'register_meds_screen.dart';
import 'alerts_screen.dart';
import 'consumption_history_screen.dart';
import 'edit_user_screen.dart';
import 'view_meds_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/profile_pictures/${user.uid}.png';
      final file = File(path);
      if (await file.exists()) {
        setState(() {
          _profileImage = file;
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _navigateToEditProfile(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditarPerfilScreen()),
    );
    if (result == true) {
      _loadProfileImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Tela Inicial')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_profileImage != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: FileImage(_profileImage!),
              )
            else
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                    user?.photoURL ?? 'https://via.placeholder.com/250'),
              ),
            SizedBox(height: 20),
            if (user != null)
              Text('Bem-vindo(a), ${user.email}!',
                  style: TextStyle(fontSize: 18))
            else
              Text('Você não está logado.', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CadastroMedicamentosScreen()),
                );
              },
              child: Text('Cadastro de Medicamentos'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ViewMedicamentosScreen()),
                );
              },
              child: Text('Visualizar Medicamentos'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AlertasLembretesScreen()),
                );
              },
              child: Text('Alertas e Lembretes'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HistoricoConsumoScreen()),
                );
              },
              child: Text('Histórico de Consumo'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _navigateToEditProfile(context);
              },
              child: Text('Editar Dados do Perfil'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
