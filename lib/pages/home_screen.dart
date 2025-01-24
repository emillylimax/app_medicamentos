import 'dart:async';
import 'package:app_medicamentos/pages/consumption_history_screen.dart';
import 'package:app_medicamentos/pages/edit_user_screen.dart';
import 'package:app_medicamentos/pages/register_meds_screen.dart';
import 'package:app_medicamentos/pages/view_meds_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:app_medicamentos/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

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
  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, dynamic>> _medicamentoStatus = {};
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _initializeHive();
    _notificationService.initializeNotifications();
    FirebaseMessaging.instance.subscribeToTopic('medication_reminders');
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
    _loadMedicamentosHoje();
  }

  Future<void> _loadMedicamentosHoje() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final diaSemanaAtual = _selectedDate.weekday;
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
      data['id'] = doc.id;
      return data;
    }).where((medicamento) {
      final frequencia = medicamento['frequencia'] ?? {};
      final dias = List<String>.from(frequencia['dias'] ?? []);
      return dias.contains(diaAtual);
    }).toList();

    setState(() {
      _medicamentosHoje = medicamentos;
      _categorizarMedicamentos();
      _scheduleNotifications();
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

        final agora = DateTime.now();
        final dataFormatada = DateFormat('yyyy-MM-dd').format(agora);
        final horarioMedicamento =
            DateTime(agora.year, agora.month, agora.day, hour, minute);

        if (agora.isAfter(horarioMedicamento) &&
            (_medicamentoStatus[medicamento['id']] == null ||
                _medicamentoStatus[medicamento['id']]![dataFormatada] == null ||
                _medicamentoStatus[medicamento['id']]![dataFormatada]![
                        horario] ==
                    null)) {
          _medicamentoStatus[medicamento['id']] ??= {};
          _medicamentoStatus[medicamento['id']]![dataFormatada] ??= {};
          _medicamentoStatus[medicamento['id']]![dataFormatada]![horario] = {
            'status': false,
            'horarioTomado': null,
          };
        }

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

  void _scheduleNotifications() {
    int notificationId = 0;
    for (var medicamento in _medicamentosHoje) {
      final frequencia = medicamento['frequencia'] ?? {};
      final horarios = List<String>.from(frequencia['horarios'] ?? []);
      for (var horario in horarios) {
        final timeParts = horario.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final scheduledTime = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, hour, minute);
        debugPrint(
            'Agendando notificação para: ${medicamento['nome']} às $scheduledTime');
        _notificationService.scheduleNotification(
            notificationId++,
            'Lembrete de Medicamento',
            'Está na hora de tomar o seu medicamento: ${medicamento['nome']}',
            scheduledTime);
        AndroidAlarmManager.oneShotAt(
            scheduledTime, notificationId, _triggerAlarm);
      }
    }
  }

  static Future<void> _triggerAlarm(int id) async {
    final NotificationService _notificationService = NotificationService();
    _notificationService.showNotification(
        id, 'Alarme de Medicamento', 'Está na hora de tomar o seu medicamento');
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

  Future<void> _marcarComoTomado(String medicamentoId, String horario) async {
    final medicamentoRef = FirebaseFirestore.instance
        .collection('medicamentos')
        .doc(medicamentoId);

    final medicamentoSnapshot = await medicamentoRef.get();
    final medicamentoData = medicamentoSnapshot.data() as Map<String, dynamic>;

    final agora = DateTime.now();
    final dataFormatada = DateFormat('yyyy-MM-dd').format(agora);
    final horarioTomado = DateFormat('HH:mm').format(agora);

    final horariosTomados =
        List<String>.from(medicamentoData['horariosTomados'] ?? []);
    horariosTomados.add("$dataFormatada $horario");

    await medicamentoRef.update({
      'horariosTomados': horariosTomados,
    });

    await FirebaseFirestore.instance.collection('consumo').add({
      'medicamentoId': medicamentoId,
      'nome': medicamentoData['nome'],
      'horario': horario,
      'data': agora.toIso8601String(),
    });

    setState(() {
      if (_medicamentoStatus[medicamentoId] == null) {
        _medicamentoStatus[medicamentoId] = {};
      }
      if (_medicamentoStatus[medicamentoId]![dataFormatada] == null) {
        _medicamentoStatus[medicamentoId]![dataFormatada] = {};
      }
      _medicamentoStatus[medicamentoId]![dataFormatada]![horario] = {
        'status': true,
        'horarioTomado': horarioTomado,
      };
    });
  }

  Future<void> _marcarComoNaoTomado(
      String medicamentoId, String horario) async {
    final medicamentoRef = FirebaseFirestore.instance
        .collection('medicamentos')
        .doc(medicamentoId);

    final medicamentoSnapshot = await medicamentoRef.get();
    final medicamentoData = medicamentoSnapshot.data() as Map<String, dynamic>;

    final hoje = DateTime.now();
    final dataFormatada = DateFormat('yyyy-MM-dd').format(hoje);

    final horariosTomados =
        List<String>.from(medicamentoData['horariosTomados'] ?? []);
    horariosTomados.remove("$dataFormatada $horario");

    await medicamentoRef.update({
      'horariosTomados': horariosTomados,
    });

    final consumoSnapshot = await FirebaseFirestore.instance
        .collection('consumo')
        .where('medicamentoId', isEqualTo: medicamentoId)
        .where('horario', isEqualTo: horario)
        .get();

    for (var doc in consumoSnapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      if (_medicamentoStatus[medicamentoId] == null) {
        _medicamentoStatus[medicamentoId] = {};
      }
      if (_medicamentoStatus[medicamentoId]![dataFormatada] == null) {
        _medicamentoStatus[medicamentoId]![dataFormatada] = {};
      }
      _medicamentoStatus[medicamentoId]![dataFormatada]![horario] = {
        'status': false,
        'horarioTomado': null,
      };
    });
  }

  Widget _buildMedicamentoCard(Map<String, dynamic> medicamento) {
    final nome = medicamento['nome'] ?? 'Sem Nome';
    final dosagem = medicamento['dosagem'] ?? 'Sem Dosagem';
    final horario = medicamento['horario'] ?? 'Sem Horário';
    final observacoes = medicamento['observacoes'] ?? 'Sem Observações';
    final dataFormatada = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final statusData =
        _medicamentoStatus[medicamento['id']]?[dataFormatada]?[horario];
    final status = statusData?['status'];
    final horarioTomado = statusData?['horarioTomado'];
    final cardColor = status == true
        ? Colors.green[100]
        : status == false
            ? Colors.red[100]
            : Colors.white;

    return Card(
      color: cardColor,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(nome, style: TextStyle(fontSize: 18)),
        subtitle: Text(
            'Dosagem: $dosagem\nHorário: $horario\nObservações: $observacoes' +
                (horarioTomado != null
                    ? '\nHorário que tomou: $horarioTomado'
                    : '')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _marcarComoTomado(medicamento['id'], horario),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _marcarComoNaoTomado(medicamento['id'], horario),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final daysOfWeek = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weekDays =
        List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: weekDays.map((date) {
        final isToday = date.day == today.day &&
            date.month == today.month &&
            date.year == today.year;
        final isSelected = date.day == _selectedDate.day &&
            date.month == _selectedDate.month &&
            date.year == _selectedDate.year;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              _loadMedicamentosHoje();
            });
          },
          child: Column(
            children: [
              Text(daysOfWeek[date.weekday - 1],
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 4),
              CircleAvatar(
                radius: 20,
                backgroundColor: isSelected ? Colors.blue : Colors.grey,
                child: Text(
                  date.day.toString(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tela Inicial'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('Cadastro de Medicamentos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CadastroMedicamentosScreen(
                      onSave: _salvarMedicamento,
                    ),
                  ),
                ).then((_) => _loadMedicamentosHoje());
              },
            ),
            ListTile(
              leading: Icon(Icons.view_list),
              title: Text('Visualizar Medicamentos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewMedicamentosScreen(),
                  ),
                ).then((_) => _loadMedicamentosHoje());
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Histórico de Consumo'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoricoConsumoScreen(),
                  ),
                ).then((_) => _loadMedicamentosHoje());
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Editar Dados do Perfil'),
              onTap: () {
                _navigateToEditProfile(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Sair'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
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
                _buildWeekCalendar(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
