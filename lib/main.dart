import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'veritasfood',
      theme: ThemeData.dark(),
      home: MyHomePage(title: 'veritasfood', camera: cameras.first),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.camera});

  final String title;
  final CameraDescription camera;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _picker = ImagePicker();
  String responseText = "";

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid && await _isAndroid33orHigher()) {
      var permission = await Permission.photos.request();
      return permission.isGranted;
    } else {
      var permission = await Permission.storage.request();
      return permission.isGranted;
    }
  }

  Future<bool> _isAndroid33orHigher() async {
    var info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 33;
  }

  Future<bool> _requestCameraPermission() async {
    if (await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    var permissionStatus = await Permission.camera.request();

    if (!mounted) return false;

    if (permissionStatus.isGranted) {
      return true;
    } else if (permissionStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to use this feature.'),
          ),
        );
      }
      return false;
    }

    return false;
  }

  void _showPicker(context) {
    showModalBottomSheet(
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('gallery'),
                onTap: () async {
                  bool permissionGranted = await _requestGalleryPermission();
                  if (permissionGranted) {
                    _imgFromGallery();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access to the gallery is denied'),
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('camera'),
                onTap: () async {
                  bool permissionGranted = await _requestCameraPermission();
                  if (permissionGranted) {
                    _imgFromCamera();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access to the camera is denied'),
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _imgFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _sendImageToServer(image);
    }
  }

  Future<void> _imgFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _sendImageToServer(image);
    }
  }

  Future<void> _sendImageToServer(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse('http://127.0.0.1:11434/api/chat');
      final headers = {'Content-Type': 'application/json'};
      final data = {
        "model": "llava",
        "messages": [
          {
            "role": "user",
            "content": "Can you tell me what the following image depicts?",
            "images": [base64Image]
          }
        ],
        "stream": false
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        setState(() {
          responseText = jsonDecode(response.body).toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Response: $responseText')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(widget.title)),
      ),
      body: Center(
        child: Text(responseText),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showPicker(context);
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
