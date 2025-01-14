import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CadastroMedicamentosScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  CadastroMedicamentosScreen({required this.onSave});

  @override
  _CadastroMedicamentosScreenState createState() =>
      _CadastroMedicamentosScreenState();
}

class _CadastroMedicamentosScreenState
    extends State<CadastroMedicamentosScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _dosagemController = TextEditingController();
  final TextEditingController _duracaoController = TextEditingController();

  List<String> _diasSelecionados = [];
  String _horarioSelecionado = '08:00';
  String _duracaoSelecionada = 'Contínuo';

  void _toggleDia(String dia) {
    setState(() {
      if (_diasSelecionados.contains(dia)) {
        _diasSelecionados.remove(dia);
      } else {
        _diasSelecionados.add(dia);
      }
    });
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

  void _salvarMedicamento() {
    if (_nomeController.text.isEmpty ||
        _dosagemController.text.isEmpty ||
        _diasSelecionados.isEmpty ||
        _horarioSelecionado.isEmpty ||
        _duracaoController.text.isEmpty) {
      return;
    }

    final medicamento = {
      'nome': _nomeController.text,
      'dosagem': _dosagemController.text,
      'frequencia': {'dias': _diasSelecionados, 'horario': _horarioSelecionado},
      'duracao': _duracaoController.text,
    };

    widget.onSave(medicamento);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cadastro de Medicamentos')),
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
                  hours: TimeOfDay.now().hour, minutes: TimeOfDay.now().minute),
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
              onPressed: _salvarMedicamento,
              child: Text('Salvar Medicamento'),
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
