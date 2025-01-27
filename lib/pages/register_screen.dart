import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _isLoading = false;

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

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      User? user =
          await authService.registerWithEmailAndPassword(email, password);
      if (user != null) {
        await authService.updateUserProfile(name: name);
        await authService.addUserToFirestore(user.uid, name, dob, email);

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      String errorMessage;
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este e-mail já está em uso. Tente outro.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Formato de e-mail inválido. Verifique o e-mail.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'A senha é muito fraca. Tente uma senha mais forte.';
        } else {
          errorMessage = 'Erro ao tentar registrar: ${e.message}';
        }
      } else {
        errorMessage = 'Erro ao tentar registrar: ${e.toString()}';
      }

      _showErrorDialog(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  void _cancelRegistration() {
    Navigator.pop(context);
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
                decoration: InputDecoration(
                  labelText: 'Nome Completo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Data de Nascimento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                decoration: InputDecoration(
                  labelText: 'Data de Nascimento',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createAccountWithEmailPassword,
                      child: Text('Registrar'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _cancelRegistration,
                child: Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
