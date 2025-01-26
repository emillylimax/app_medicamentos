import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPrescriptionsScreen extends StatefulWidget {
  @override
  _SavedPrescriptionsScreenState createState() =>
      _SavedPrescriptionsScreenState();
}

class _SavedPrescriptionsScreenState extends State<SavedPrescriptionsScreen> {
  List<String> _prescriptions = [];

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  _loadPrescriptions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _prescriptions = prefs.getStringList('prescriptions') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Prescriptions'),
      ),
      body: ListView.builder(
        itemCount: _prescriptions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_prescriptions[index]),
          );
        },
      ),
    );
  }
}
