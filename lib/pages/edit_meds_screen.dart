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
  late TextEditingController _observacoesController;
  late TextEditingController _quantidadeController;

  List<String> _diasSelecionados = [];
  List<TextEditingController> _horariosControllers = [
    TextEditingController(text: '08:00')
  ];
  String _duracaoSelecionada = 'Contínuo';
  String _unidadeSelecionada = '';
  String _unidadeQuantidadeSelecionada = '';
  late Box _medicamentosBox;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _nomeController =
        TextEditingController(text: widget.currentData['nome'] ?? '');
    _dosagemController = TextEditingController(
        text: _extractDosagem(widget.currentData['dosagem']));
    _duracaoController =
        TextEditingController(text: widget.currentData['duracao'] ?? '');
    _observacoesController =
        TextEditingController(text: widget.currentData['observacoes'] ?? '');
    _quantidadeController = TextEditingController(
        text: _extractQuantidade(widget.currentData['quantidade']));
    _unidadeSelecionada = _extractUnidade(widget.currentData['dosagem']);
    _unidadeQuantidadeSelecionada =
        _extractUnidadeQuantidade(widget.currentData['quantidade']);

    if (widget.currentData['frequencia'] != null) {
      _diasSelecionados =
          List<String>.from(widget.currentData['frequencia']['dias'] ?? []);
      _horariosControllers = List<String>.from(
              widget.currentData['frequencia']['horarios'] ?? ['08:00'])
          .map((horario) => TextEditingController(text: horario))
          .toList();
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

  String _extractDosagem(String? dosagem) {
    if (dosagem == null) return '';
    return dosagem.split(' ').first;
  }

  String _extractUnidade(String? dosagem) {
    if (dosagem == null) return '';
    return dosagem.split(' ').last;
  }

  String _extractQuantidade(String? quantidade) {
    if (quantidade == null) return '';
    return quantidade.split(' ').first;
  }

  String _extractUnidadeQuantidade(String? quantidade) {
    if (quantidade == null) return '';
    return quantidade.split(' ').last;
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
        _horariosControllers.isEmpty ||
        _duracaoController.text.isEmpty ||
        _quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Todos os campos devem ser preenchidos')),
      );
      return;
    }

    final horarios =
        _horariosControllers.map((controller) => controller.text).toList();

    final medicamento = {
      'nome': _nomeController.text,
      'dosagem': '${_dosagemController.text} $_unidadeSelecionada',
      'quantidade':
          '${_quantidadeController.text} $_unidadeQuantidadeSelecionada',
      'frequencia': {
        'dias': _diasSelecionados,
        'horarios': horarios,
      },
      'duracao': _duracaoSelecionada,
      'observacoes': _observacoesController.text,
    };

    if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
      try {
        await FirebaseFirestore.instance
            .collection('medicamentos')
            .doc(widget.medicamentoId)
            .update(medicamento);

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

  void _adicionarHorario() {
    setState(() {
      _horariosControllers.add(TextEditingController(text: '08:00'));
    });
  }

  void _removerHorario(int index) {
    setState(() {
      _horariosControllers.removeAt(index);
    });
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_nomeController, 'Nome do Medicamento'),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_dosagemController, 'Dosagem'),
                  ),
                  SizedBox(width: 8),
                  _buildDropdownButton(
                    value: _unidadeSelecionada,
                    items: ['mg', 'g', 'mcg', 'ml', 'UI'],
                    onChanged: (String? newValue) {
                      setState(() {
                        _unidadeSelecionada = newValue!;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_quantidadeController, 'Quantidade'),
                  ),
                  SizedBox(width: 8),
                  _buildDropdownButton(
                    value: _unidadeQuantidadeSelecionada,
                    items: ['comprimido', 'cápsula', 'gotas', 'ml'],
                    onChanged: (String? newValue) {
                      setState(() {
                        _unidadeQuantidadeSelecionada = newValue!;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildTextField(_observacoesController, 'Observações',
                  maxLines: 3),
              SizedBox(height: 12),
              _buildDuracao(),
              SizedBox(height: 12),
              _buildHorariosSelecionados(),
              SizedBox(height: 12),
              _buildDiasSelecionados(),
              SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _salvarAlteracoes,
                      child: Text('Salvar Alterações'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildDropdownButton({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButton<String>(
      value: value,
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  Widget _buildDiasSelecionados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escolha os dias:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDiaButton('Segunda'),
                  SizedBox(width: 8),
                  _buildDiaButton('Terça'),
                  SizedBox(width: 8),
                  _buildDiaButton('Quarta'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDiaButton('Quinta'),
                  SizedBox(width: 8),
                  _buildDiaButton('Sexta'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDiaButton('Sábado'),
                  SizedBox(width: 8),
                  _buildDiaButton('Domingo'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiaButton(String dia) {
    bool isSelected = _diasSelecionados.contains(dia);
    return ElevatedButton(
      onPressed: () => _toggleDia(dia),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.blue : const Color.fromARGB(255, 82, 82, 82),
      ),
      child: Text(dia),
    );
  }

  Widget _buildHorariosSelecionados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horários:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            ..._horariosControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removerHorario(index),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
        Center(
          child: ElevatedButton(
            onPressed: _adicionarHorario,
            child: Text('Adicionar Horário'),
          ),
        ),
      ],
    );
  }

  Widget _buildDuracao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escolha a frequência:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _duracaoSelecionada = 'Contínuo';
                    _duracaoController.text = _duracaoSelecionada;
                  });
                },
                child: Text('Contínuo'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _selecionarDuracaoPersonalizada,
                child: Text('Personalizado'),
              ),
            ),
          ],
        ),
        _buildTextField(_duracaoController, 'Duração do Tratamento',
            maxLines: 1),
      ],
    );
  }
}
