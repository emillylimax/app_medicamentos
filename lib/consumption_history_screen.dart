import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HistoricoConsumoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Histórico de Consumo')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('consumo').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var consumoDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: consumoDocs.length,
            itemBuilder: (context, index) {
              var consumo = consumoDocs[index];
              return ListTile(
                title: Text(consumo['nome']),
                subtitle: Text('Tomado: ${consumo['data']}'),
              );
            },
          );
        },
      ),
    );
  }
}
