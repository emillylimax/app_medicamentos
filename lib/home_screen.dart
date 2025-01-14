import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'register_meds_screen.dart';
import 'alerts_screen.dart';
import 'consumption_history_screen.dart';
import 'edit_user_screen.dart';
import 'view_meds_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  File? _profileImage;
  late Box _medicamentosBox;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _initializeHive();
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
    await Hive.initFlutter();
    _medicamentosBox = await Hive.openBox('medicamentos');
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

  Future<void> _syncLocalDataWithFirebase() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final localData = _medicamentosBox.values.toList();
    for (var medicamento in localData) {
      await FirebaseFirestore.instance.collection('medicamentos').add({
        'uid': user.uid,
        'nome': medicamento['nome'],
        'dosagem': medicamento['dosagem'],
        'frequencia': medicamento['frequencia'],
        'duracao': medicamento['duracao'],
      });
    }
    _medicamentosBox.clear();
  }

  Future<void> _salvarMedicamentoLocalmente(
      Map<String, dynamic> medicamento) async {
    await _medicamentosBox.add(medicamento);
  }

  Future<void> _salvarMedicamento(Map<String, dynamic> medicamento) async {
    if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
      User? user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('medicamentos').add({
          'uid': user.uid,
          'nome': medicamento['nome'],
          'dosagem': medicamento['dosagem'],
          'frequencia': medicamento['frequencia'],
          'duracao': medicamento['duracao'],
        });
      }
    } else {
      await _salvarMedicamentoLocalmente(medicamento);
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
                      builder: (context) => CadastroMedicamentosScreen(
                            onSave: _salvarMedicamento,
                          )),
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
