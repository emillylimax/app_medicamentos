import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_meds_screen.dart';

class ViewMedicamentosScreen extends StatefulWidget {
  @override
  _ViewMedicamentosScreenState createState() => _ViewMedicamentosScreenState();
}

class _ViewMedicamentosScreenState extends State<ViewMedicamentosScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Medicamentos Cadastrados')),
        body: Center(child: Text('Você não está logado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Medicamentos Cadastrados'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medicamentos')
            .where('uid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Nenhum medicamento cadastrado.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final medicamentos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: medicamentos.length,
            itemBuilder: (context, index) {
              final medicamento = medicamentos[index];
              final nome = medicamento['nome'] ?? 'Sem Nome';
              final dosagem = medicamento['dosagem'] ?? 'Sem Dosagem';
              final frequencia = medicamento['frequencia'] ?? {};
              final duracao = medicamento['duracao'] ?? 'Sem Duração';
              final observacoes = medicamento.data() != null &&
                      (medicamento.data() as Map<String, dynamic>)
                          .containsKey('observacoes')
                  ? medicamento['observacoes']
                  : 'Sem Observações';

              List<String> dias = frequencia['dias'] != null
                  ? List<String>.from(frequencia['dias'])
                  : [];
              String diasFormatados =
                  dias.isEmpty ? 'Sem Dias Selecionados' : dias.join(', ');

              List<String> horarios = frequencia['horarios'] != null
                  ? List<String>.from(frequencia['horarios'])
                  : [];
              String horariosFormatados = horarios.isEmpty
                  ? 'Sem Horários Selecionados'
                  : horarios.join(', ');

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(nome, style: TextStyle(fontSize: 18)),
                  subtitle: Text(
                      'Dosagem: $dosagem\nFrequência: $diasFormatados\nHorários: $horariosFormatados\nDuração: $duracao\nObservações: $observacoes'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditMedicamentoScreen(
                                medicamentoId: medicamento.id,
                                currentData:
                                    medicamento.data() as Map<String, dynamic>,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Medicamento atualizado com sucesso')),
                              );
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Excluir Medicamento'),
                              content:
                                  Text('Deseja realmente excluir "$nome"?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          );

                          if (confirmar == true) {
                            await medicamento.reference.delete();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
