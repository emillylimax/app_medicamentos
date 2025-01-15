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
  final TextEditingController _observacoesController = TextEditingController();

  List<String> _diasSelecionados = [];
  List<String> _horariosSelecionados = ['08:00'];
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

  void _adicionarHorario() {
    setState(() {
      _horariosSelecionados.add('08:00');
    });
  }

  void _removerHorario(int index) {
    setState(() {
      _horariosSelecionados.removeAt(index);
    });
  }

  void _atualizarHorario(int index, Duration duration) {
    final hour = duration.inHours;
    final minute = duration.inMinutes % 60;
    setState(() {
      _horariosSelecionados[index] =
          '$hour:${minute.toString().padLeft(2, '0')}';
    });
  }

  void _salvarMedicamento() {
    if (_nomeController.text.isEmpty ||
        _dosagemController.text.isEmpty ||
        _diasSelecionados.isEmpty ||
        _horariosSelecionados.isEmpty ||
        _duracaoController.text.isEmpty) {
      return;
    }

    final medicamento = {
      'nome': _nomeController.text,
      'dosagem': _dosagemController.text,
      'frequencia': {
        'dias': _diasSelecionados,
        'horarios': _horariosSelecionados,
      },
      'duracao': _duracaoController.text,
      'observacoes': _observacoesController.text,
    };

    widget.onSave(medicamento);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cadastro de Medicamentos')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                  controller: _nomeController,
                  decoration:
                      InputDecoration(labelText: 'Nome do Medicamento')),
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
              Column(
                children: _horariosSelecionados.asMap().entries.map((entry) {
                  int index = entry.key;
                  String horario = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: CupertinoTimerPicker(
                          mode: CupertinoTimerPickerMode.hm,
                          initialTimerDuration: Duration(
                              hours: int.parse(horario.split(':')[0]),
                              minutes: int.parse(horario.split(':')[1])),
                          onTimerDurationChanged: (duration) {
                            _atualizarHorario(index, duration);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removerHorario(index),
                      ),
                    ],
                  );
                }).toList(),
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _adicionarHorario,
                    child: Text('Adicionar Horário'),
                  ),
                ],
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
              TextField(
                controller: _observacoesController,
                decoration: InputDecoration(labelText: 'Observações'),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarMedicamento,
                child: Text('Salvar Medicamento'),
              ),
            ],
          ),
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
