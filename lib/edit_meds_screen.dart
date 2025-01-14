import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EditMedicamentoScreen extends StatefulWidget {
  final String medicamentoId;
  final Map<String, dynamic> currentData;

  EditMedicamentoScreen({
    required this.medicamentoId,
    required this.currentData,
  });

  @override
  _EditMedicamentoScreenState createState() => _EditMedicamentoScreenState();
}

class _EditMedicamentoScreenState extends State<EditMedicamentoScreen> {
  late TextEditingController _nomeController;
  late TextEditingController _dosagemController;
  late TextEditingController _duracaoController;

  List<String> _diasSelecionados = [];
  String _horarioSelecionado = '08:00';
  String _duracaoSelecionada = 'Contínuo';
  late Box _medicamentosBox;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _nomeController =
        TextEditingController(text: widget.currentData['nome'] ?? '');
    _dosagemController =
        TextEditingController(text: widget.currentData['dosagem'] ?? '');
    _duracaoController =
        TextEditingController(text: widget.currentData['duracao'] ?? '');

    if (widget.currentData['frequencia'] != null) {
      _diasSelecionados =
          List<String>.from(widget.currentData['frequencia']['dias'] ?? []);
      _horarioSelecionado =
          widget.currentData['frequencia']['horario'] ?? '08:00';
    }

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
    _medicamentosBox = await Hive.openBox('medicamentos');
  }

  Future<void> _salvarAlteracoes() async {
    if (_nomeController.text.isEmpty ||
        _dosagemController.text.isEmpty ||
        _diasSelecionados.isEmpty ||
        _horarioSelecionado.isEmpty ||
        _duracaoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Todos os campos devem ser preenchidos')),
      );
      return;
    }

    final medicamento = {
      'nome': _nomeController.text,
      'dosagem': _dosagemController.text,
      'frequencia': {
        'dias': _diasSelecionados,
        'horario': _horarioSelecionado,
      },
      'duracao': _duracaoController.text,
    };

    if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
      try {
        await FirebaseFirestore.instance
            .collection('medicamentos')
            .doc(widget.medicamentoId)
            .update(medicamento);

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Medicamento atualizado com sucesso')),
        // );

        Navigator.pop(context, true);
      } catch (e) {
        print('Erro ao atualizar medicamento: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar medicamento')),
        );
      }
    } else {
      await _salvarMedicamentoLocalmente(medicamento);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sem conexão. Dados salvos localmente.')),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _salvarMedicamentoLocalmente(
      Map<String, dynamic> medicamento) async {
    await _medicamentosBox.put(widget.medicamentoId, medicamento);
  }

  Future<void> _syncLocalDataWithFirebase() async {
    final localData = _medicamentosBox.toMap();
    for (var medicamentoId in localData.keys) {
      final medicamento = localData[medicamentoId];
      await FirebaseFirestore.instance
          .collection('medicamentos')
          .doc(medicamentoId)
          .update(medicamento);
    }
    await _medicamentosBox.clear();
  }

  Future<void> _selecionarDuracaoPersonalizada() async {
    String? quantidadeDias = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();

        return AlertDialog(
          title: Text('Quantos dias irá tomar?'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Quantidade de dias'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (quantidadeDias != null) {
      setState(() {
        _duracaoSelecionada = '$quantidadeDias dias';
        _duracaoController.text = _duracaoSelecionada;
      });
    }
  }

  void _toggleDia(String dia) {
    setState(() {
      if (_diasSelecionados.contains(dia)) {
        _diasSelecionados.remove(dia);
      } else {
        _diasSelecionados.add(dia);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Medicamento')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Nome do Medicamento')),
            TextField(
                controller: _dosagemController,
                decoration: InputDecoration(labelText: 'Dosagem')),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _buildDiaButton('Segunda'),
                _buildDiaButton('Terça'),
                _buildDiaButton('Quarta'),
                _buildDiaButton('Quinta'),
                _buildDiaButton('Sexta'),
                _buildDiaButton('Sábado'),
                _buildDiaButton('Domingo'),
              ],
            ),
            CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: Duration(
                  hours: int.parse(_horarioSelecionado.split(':')[0]),
                  minutes: int.parse(_horarioSelecionado.split(':')[1])),
              onTimerDurationChanged: (duration) {
                final hour = duration.inHours;
                final minute = duration.inMinutes % 60;
                setState(() {
                  _horarioSelecionado =
                      '$hour:${minute.toString().padLeft(2, '0')}';
                });
              },
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _duracaoSelecionada = 'Contínuo';
                      _duracaoController.text = _duracaoSelecionada;
                    });
                  },
                  child: Text('Contínuo'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _selecionarDuracaoPersonalizada,
                  child: Text('Personalizado'),
                ),
              ],
            ),
            TextField(
              controller: _duracaoController,
              decoration: InputDecoration(labelText: 'Duração do Tratamento'),
              enabled: false,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _salvarAlteracoes,
              child: Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaButton(String dia) {
    bool isSelected = _diasSelecionados.contains(dia);
    return ElevatedButton(
      onPressed: () => _toggleDia(dia),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey,
      ),
      child: Text(dia),
    );
  }
}
