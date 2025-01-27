import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterHealthInfoScreen extends StatefulWidget {
  @override
  _RegisterHealthInfoScreenState createState() =>
      _RegisterHealthInfoScreenState();
}

class _RegisterHealthInfoScreenState extends State<RegisterHealthInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _glucoseController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveHealthInfo() async {
    if (_formKey.currentState!.validate()) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final systolic = _systolicController.text.isNotEmpty
          ? int.parse(_systolicController.text)
          : null;
      final diastolic = _diastolicController.text.isNotEmpty
          ? int.parse(_diastolicController.text)
          : null;
      final heartRate = _heartRateController.text.isNotEmpty
          ? int.parse(_heartRateController.text)
          : null;
      final glucose = _glucoseController.text.isNotEmpty
          ? int.parse(_glucoseController.text)
          : null;
      final weight = _weightController.text.isNotEmpty
          ? double.parse(_weightController.text)
          : null;
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      await FirebaseFirestore.instance.collection('health_info').add({
        'uid': user.uid,
        'systolic': systolic,
        'diastolic': diastolic,
        'heartRate': heartRate,
        'glucose': glucose,
        'weight': weight,
        'timestamp': formattedDate,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informações de saúde salvas com sucesso!')),
      );

      _formKey.currentState!.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Informações de Saúde'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Preencha as informações abaixo:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 40),
                TextFormField(
                  controller: _systolicController,
                  decoration: InputDecoration(
                    labelText: 'Pressão Sistólica (mmHg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _diastolicController,
                  decoration: InputDecoration(
                    labelText: 'Pressão Diastólica (mmHg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite_border),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _heartRateController,
                  decoration: InputDecoration(
                    labelText: 'Batimentos Cardíacos (bpm)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _glucoseController,
                  decoration: InputDecoration(
                    labelText: 'Glicemia (mg/dL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bloodtype),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveHealthInfo,
                  child: Text('Salvar Informações'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.red,
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
