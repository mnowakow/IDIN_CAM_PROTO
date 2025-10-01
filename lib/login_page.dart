import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/login_page_notifier.dart';

class LoginPage extends StatefulWidget {
  final LoginPageNotifier lpNotifier;
  final GlobalKey<NavigatorState> nav;

  const LoginPage(this.lpNotifier, this.nav, {super.key});

  @override
  State<StatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String username = "";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: Card(
        color: const Color.fromARGB(255, 211, 206, 206),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0.0, 400, 0.0, 0.0),
          child: Column(
            spacing: 40.0,
            children: [
              Icon(Icons.person, size: 50.0),
              SizedBox(
                height: 50,
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      username = value;
                    });
                  },
                ),
              ),
              FloatingActionButton(
                backgroundColor: Colors.lightBlue,
                onPressed: () {
                  setState(() {
                    widget.lpNotifier.loggedIn(username);
                    widget.nav.currentState?.pop();
                  });
                },
                child: Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
