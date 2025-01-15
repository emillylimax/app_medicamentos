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
  List<Map<String, dynamic>> _medicamentosHoje = [];
  List<Map<String, dynamic>> _medicamentosManha = [];
  List<Map<String, dynamic>> _medicamentosTarde = [];
  List<Map<String, dynamic>> _medicamentosNoite = [];
  String? _userName;

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
    _loadUserName();
    _loadMedicamentosHoje();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMedicamentosHoje();
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

  Future<void> _loadUserName() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _userName = data['name'];
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
    _loadMedicamentosHoje(); // Recarregar medicamentos após salvar
  }

  Future<void> _loadMedicamentosHoje() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final diaSemanaAtual = DateTime.now().weekday;
    final diasSemana = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado'
    ];
    final diaAtual = diasSemana[diaSemanaAtual % 7];

    final snapshot = await FirebaseFirestore.instance
        .collection('medicamentos')
        .where('uid', isEqualTo: user.uid)
        .get();

    final medicamentos = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Adicionar o ID do documento
      return data;
    }).where((medicamento) {
      final frequencia = medicamento['frequencia'] ?? {};
      final dias = List<String>.from(frequencia['dias'] ?? []);
      return dias.contains(diaAtual);
    }).toList();

    setState(() {
      _medicamentosHoje = medicamentos;
      _categorizarMedicamentos();
    });
  }

  void _categorizarMedicamentos() {
    _medicamentosManha.clear();
    _medicamentosTarde.clear();
    _medicamentosNoite.clear();

    for (var medicamento in _medicamentosHoje) {
      final frequencia = medicamento['frequencia'] ?? {};
      final horarios = List<String>.from(frequencia['horarios'] ?? []);

      for (var horario in horarios) {
        final timeParts = horario.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        if (hour >= 1 && hour < 12) {
          _medicamentosManha.add({...medicamento, 'horario': horario});
        } else if (hour >= 12 && hour < 18) {
          _medicamentosTarde.add({...medicamento, 'horario': horario});
        } else {
          _medicamentosNoite.add({...medicamento, 'horario': horario});
        }
      }
    }

    _medicamentosManha.sort((a, b) => a['horario'].compareTo(b['horario']));
    _medicamentosTarde.sort((a, b) => a['horario'].compareTo(b['horario']));
    _medicamentosNoite.sort((a, b) => a['horario'].compareTo(b['horario']));
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
      _loadUserName();
    }
  }

  Future<void> _marcarComoTomado(String medicamentoId) async {
    await FirebaseFirestore.instance
        .collection('medicamentos')
        .doc(medicamentoId)
        .update({'tomado': true});
    _loadMedicamentosHoje();
  }

  Future<void> _marcarComoNaoTomado(String medicamentoId) async {
    await FirebaseFirestore.instance
        .collection('medicamentos')
        .doc(medicamentoId)
        .update({'tomado': false});
    _loadMedicamentosHoje();
  }

  Widget _buildMedicamentoCard(Map<String, dynamic> medicamento) {
    final nome = medicamento['nome'] ?? 'Sem Nome';
    final dosagem = medicamento['dosagem'] ?? 'Sem Dosagem';
    final frequencia = medicamento['frequencia'] ?? {};
    final horarios = List<String>.from(frequencia['horarios'] ?? []);
    final horariosFormatados = horarios.join(', ');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(nome, style: TextStyle(fontSize: 18)),
        subtitle: Text('Dosagem: $dosagem\nHorários: $horariosFormatados'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _marcarComoTomado(medicamento['id']),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _marcarComoNaoTomado(medicamento['id']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Tela Inicial')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                  Text('Bem-vindo(a), ${_userName ?? user.email}!',
                      style: TextStyle(fontSize: 18))
                else
                  Text('Você não está logado.', style: TextStyle(fontSize: 18)),
                SizedBox(height: 20),
                if (_medicamentosManha.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manhã',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      ..._medicamentosManha.map(_buildMedicamentoCard).toList(),
                    ],
                  ),
                if (_medicamentosTarde.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tarde',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      ..._medicamentosTarde.map(_buildMedicamentoCard).toList(),
                    ],
                  ),
                if (_medicamentosNoite.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Noite',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      ..._medicamentosNoite.map(_buildMedicamentoCard).toList(),
                    ],
                  ),
                if (_medicamentosManha.isEmpty &&
                    _medicamentosTarde.isEmpty &&
                    _medicamentosNoite.isEmpty)
                  Text('Nenhum medicamento marcado para hoje.',
                      style: TextStyle(fontSize: 18)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CadastroMedicamentosScreen(
                                onSave: _salvarMedicamento,
                              )),
                    ).then((_) =>
                        _loadMedicamentosHoje()); // Recarregar após voltar
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
                    ).then((_) =>
                        _loadMedicamentosHoje()); // Recarregar após voltar
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
                    ).then((_) =>
                        _loadMedicamentosHoje()); // Recarregar após voltar
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
                    ).then((_) =>
                        _loadMedicamentosHoje()); // Recarregar após voltar
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
        ),
      ),
    );
  }
}
