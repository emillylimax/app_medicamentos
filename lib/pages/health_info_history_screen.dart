import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthInfoHistoryScreen extends StatefulWidget {
  @override
  _HealthInfoHistoryScreenState createState() =>
      _HealthInfoHistoryScreenState();
}

class _HealthInfoHistoryScreenState extends State<HealthInfoHistoryScreen> {
  List<Map<String, dynamic>> _healthInfoList = [];
  Map<String, Map<String, List<double>>> _dailyData = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadHealthInfo();
  }

  Future<void> _loadHealthInfo() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('health_info')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final healthInfoList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _healthInfoList = healthInfoList;
        _calculateDailyData();
      });

      debugPrint('Health Info List: $_healthInfoList');
    } catch (e) {
      debugPrint('Erro ao carregar informações de saúde: $e');
    }
  }

  void _calculateDailyData() {
    _dailyData = {
      'systolic': {},
      'diastolic': {},
      'heartRate': {},
      'glucose': {},
      'weight': {},
    };

    for (var info in _healthInfoList) {
      final timestamp = DateTime.parse(info['timestamp']);
      final day = DateFormat('yyyy-MM-dd').format(timestamp);
      _dailyData['systolic']?[day] ??= [];
      _dailyData['diastolic']?[day] ??= [];
      _dailyData['heartRate']?[day] ??= [];
      _dailyData['glucose']?[day] ??= [];
      _dailyData['weight']?[day] ??= [];

      if (info['systolic'] != null && info['systolic'] != 0) {
        _dailyData['systolic']?[day]?.add(info['systolic'].toDouble());
      }
      if (info['diastolic'] != null && info['diastolic'] != 0) {
        _dailyData['diastolic']?[day]?.add(info['diastolic'].toDouble());
      }
      if (info['heartRate'] != null && info['heartRate'] != 0) {
        _dailyData['heartRate']?[day]?.add(info['heartRate'].toDouble());
      }
      if (info['glucose'] != null && info['glucose'] != 0) {
        _dailyData['glucose']?[day]?.add(info['glucose'].toDouble());
      }
      if (info['weight'] != null && info['weight'] != 0) {
        _dailyData['weight']?[day]?.add(info['weight'].toDouble());
      }
    }

    debugPrint('Daily Data: $_dailyData');
  }

  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  String _getUnit(String field) {
    switch (field) {
      case 'systolic':
      case 'diastolic':
        return 'mmHg';
      case 'heartRate':
        return 'bpm';
      case 'glucose':
        return 'mg/dL';
      case 'weight':
        return 'kg';
      default:
        return '';
    }
  }

  Widget _buildHealthInfoCard(
      String title, List<Map<String, dynamic>> data, String field) {
    final days = _dailyData[field]?.keys.toList() ?? [];
    final averages = days.map((day) {
      final values = _dailyData[field]?[day] ?? [];
      return _calculateAverage(values);
    }).toList();
    final unit = _getUnit(field);

    debugPrint('Days: $days');
    debugPrint('Averages: $averages');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        children: [
          ...data.map((info) {
            final timestamp = DateTime.parse(info['timestamp']);
            final formattedDate = DateFormat('dd-MM-yyyy').format(timestamp);
            final formattedTime = DateFormat('HH:mm').format(timestamp);
            final value =
                info[field]?.toString() ?? 'N/A'; // Ensure value is not null
            return Card(
              color: const Color.fromARGB(255, 44, 44, 44),
              margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListTile(
                title: Center(
                  child: Text(
                    '$value $unit',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Data: $formattedDate',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    Text(
                      'Hora: $formattedTime',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Médias Diárias'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: days.asMap().entries.map((entry) {
                          final index = entry.key;
                          final day = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: const Color.fromARGB(
                                          221, 255, 255, 255)),
                                ),
                                Text(
                                  '${averages[index].toStringAsFixed(2)} $unit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Fechar'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text('Ver Médias'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systolicData = _healthInfoList
        .where((info) => info['systolic'] != null)
        .map((info) =>
            {'timestamp': info['timestamp'], 'systolic': info['systolic']})
        .toList();

    final diastolicData = _healthInfoList
        .where((info) => info['diastolic'] != null)
        .map((info) =>
            {'timestamp': info['timestamp'], 'diastolic': info['diastolic']})
        .toList();

    final heartRateData = _healthInfoList
        .where((info) => info['heartRate'] != null)
        .map((info) =>
            {'timestamp': info['timestamp'], 'heartRate': info['heartRate']})
        .toList();

    final glucoseData = _healthInfoList
        .where((info) => info['glucose'] != null)
        .map((info) =>
            {'timestamp': info['timestamp'], 'glucose': info['glucose']})
        .toList();

    final weightData = _healthInfoList
        .where((info) => info['weight'] != null)
        .map((info) =>
            {'timestamp': info['timestamp'], 'weight': info['weight']})
        .toList();

    debugPrint('Systolic Data: $systolicData');
    debugPrint('Diastolic Data: $diastolicData');
    debugPrint('Heart Rate Data: $heartRateData');
    debugPrint('Glucose Data: $glucoseData');
    debugPrint('Weight Data: $weightData');

    return Scaffold(
      appBar: AppBar(
        title: Text('Informações de Saúde'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildHealthInfoCard('Pressão Sistólica', systolicData, 'systolic'),
            _buildHealthInfoCard(
                'Pressão Diastólica', diastolicData, 'diastolic'),
            _buildHealthInfoCard(
                'Batimentos Cardíacos', heartRateData, 'heartRate'),
            _buildHealthInfoCard('Glicemia', glucoseData, 'glucose'),
            _buildHealthInfoCard('Peso', weightData, 'weight'),
          ],
        ),
      ),
    );
  }
}
