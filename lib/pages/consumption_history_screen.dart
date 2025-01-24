import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoricoConsumoScreen extends StatefulWidget {
  @override
  _HistoricoConsumoScreenState createState() => _HistoricoConsumoScreenState();
}

class _HistoricoConsumoScreenState extends State<HistoricoConsumoScreen> {
  String? _selectedMedicamento;
  List<String> _medicamentos = [];

  @override
  void initState() {
    super.initState();
    _loadMedicamentos();
  }

  Future<void> _loadMedicamentos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('medicamentos').get();
    setState(() {
      _medicamentos =
          snapshot.docs.map((doc) => doc['nome'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
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
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(consumo['nome'],
                            style: TextStyle(fontSize: 18)),
                        subtitle:
                            Text('Tomado: $formattedDate às $formattedTime'),
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
