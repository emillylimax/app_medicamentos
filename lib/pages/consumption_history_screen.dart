import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoricoConsumoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Histórico de Consumo')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('consumo')
            .orderBy('data',
                descending: true) // Ordenar pela data em ordem decrescente
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var consumoDocs = snapshot.data!.docs;
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

              var formattedDate = DateFormat('dd-MM-yyyy').format(dateTime);
              var formattedTime = DateFormat('HH:mm').format(dateTime);

              return ListTile(
                title: Text(consumo['nome']),
                subtitle: Text('Tomado: $formattedDate às $formattedTime'),
              );
            },
          );
        },
      ),
    );
  }
}
