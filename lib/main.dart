import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/annotation_notifier.dart';
import 'package:idin_cam_prototype/pdf_document_provider.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/side_bar.dart';
import 'package:idin_cam_prototype/simple_pdf_viewer.dart';

import 'package:idin_cam_prototype/login_page_notifier.dart';
import "package:provider/provider.dart";

//import 'dart:io' as io;

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PdfDocumentProvider()),
        ChangeNotifierProvider(create: (_) => AnnotationNotifier()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
  final LoginPageNotifier lpNotifier = LoginPageNotifier();
  final ScrollNotifier scrollNotifier = ScrollNotifier();

  @override
  void initState() {
    super.initState();
    // Initialize annotations on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnotationNotifier>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: nav,
      title: 'IDIN CAM Prototype',
      // routes: {'/login': (context) => LoginPage(lpNotifier, nav)},
      // initialRoute: '/login',
      home: Stack(
        children: [
          SimplePdfViewer(
            pdfAssetPath: 'assets/pdfs/lafiamma.pdf',
            isMiniview: false,
            filter: null,
            scrollNotifier: scrollNotifier,
            pageName: 'mainView',
          ),
          ExpandableSidebar(
            position: SidebarPosition.right,
            scrollNotifier: scrollNotifier,
          ),
        ],
      ),
    );
  }
}
