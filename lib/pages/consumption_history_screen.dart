import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoricoConsumoScreen extends StatefulWidget {
  @override
  _HistoricoConsumoScreenState createState() => _HistoricoConsumoScreenState();
}

class _HistoricoConsumoScreenState extends State<HistoricoConsumoScreen> {
  String? _selectedMedicamento;
  List<String> _medicamentos = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadMedicamentos();
  }

  Future<void> _loadMedicamentos() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('medicamentos')
        .where('uid', isEqualTo: user.uid)
        .get();
    setState(() {
      _medicamentos =
          snapshot.docs.map((doc) => doc['nome'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Histórico de Consumo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              hint: Text('Selecione um medicamento'),
              value: _selectedMedicamento,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMedicamento = newValue;
                });
              },
              items:
                  _medicamentos.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('consumo')
                  .where('uid', isEqualTo: user?.uid)
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum consumo cadastrado.',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                var consumoDocs = snapshot.data!.docs;
                if (_selectedMedicamento != null) {
                  consumoDocs = consumoDocs
                      .where((doc) => doc['nome'] == _selectedMedicamento)
                      .toList();
                }

                return ListView.builder(
                  itemCount: consumoDocs.length,
                  itemBuilder: (context, index) {
                    var consumo = consumoDocs[index];
                    var data = consumo['data'];
                    DateTime dateTime;

                    if (data is Timestamp) {
                      dateTime = data.toDate();
                    } else if (data is String) {
                      dateTime = DateTime.parse(data);
                    } else {
                      dateTime = DateTime.now();
                    }

                    var formattedDate =
                        DateFormat('dd-MM-yyyy').format(dateTime);
                    var formattedTime = DateFormat('HH:mm').format(dateTime);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading:
                            Icon(Icons.medical_services, color: Colors.blue),
                        title: Text(consumo['nome'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        subtitle: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                text: 'Tomado: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '$formattedDate às $formattedTime',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
