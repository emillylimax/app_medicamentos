import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  Future<void> _createAccountWithEmailPassword() async {
    String name = _nameController.text;
    String dob = DateFormat('dd-MM-yyyy').format(_selectedDate);
    String email = _emailController.text;
    String password = _passwordController.text;

    if (name.isEmpty || dob.isEmpty || email.isEmpty || password.isEmpty) {
      _showErrorDialog("Por favor, preencha todos os campos.");
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'dob': dob,
          'email': email,
        });

        await user.updateDisplayName(name);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showErrorDialog("Erro ao registrar usuário: ${e.toString()}");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Erro'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registrar Conta')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Nome Completo'),
              ),
              SizedBox(height: 20),
              Text('Data de Nascimento', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Container(
                height: 150,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _selectedDate = newDateTime;
                    });
                  },
                  maximumDate: DateTime.now(),
                  minimumYear: 1900,
                  maximumYear: DateTime.now().year,
                ),
              ),
              TextField(
                controller: TextEditingController(
                  text: DateFormat('dd-MM-yyyy').format(_selectedDate),
                ),
                decoration: InputDecoration(labelText: 'Data de Nascimento'),
                readOnly: true,
              ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'E-mail'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Senha'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAccountWithEmailPassword,
                child: Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
