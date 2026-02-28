import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://twtzpcnkwhvdlkwmmswi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3dHpwY25rd2h2ZGxrd21tc3dpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNzUxMzAsImV4cCI6MjA4Nzg1MTEzMH0.6RDCTLjqWB8GXvgSqKAv_PsQd78if0oFYD9SbvsDmmk',
  );

  runApp(const SmartPatchApp());
}

class SmartPatchApp extends StatelessWidget {
  const SmartPatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE6F2E6),
        primaryColor: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

final supabase = Supabase.instance.client;
final uuid = const Uuid();

// ------------------------- 1) Welcome Page -------------------------
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome to Smart Patch",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                "Detect leaf diseases instantly.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImageUploadPage()),
                  );
                },
                child: const Text("Start"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------- 2) Image Upload Page -------------------------
class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  void _goToResultPage() {
    if (_image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UploadResultPage(imageFile: _image!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Leaf Image")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null) Image.file(_image!, height: 250),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: const Text("Pick from Camera"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: const Text("Pick from Gallery"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _goToResultPage,
              child: const Text("Predict"),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------- 3) Upload / Result Page -------------------------
class UploadResultPage extends StatefulWidget {
  final File imageFile;

  const UploadResultPage({super.key, required this.imageFile});

  @override
  State<UploadResultPage> createState() => _UploadResultPageState();
}

class _UploadResultPageState extends State<UploadResultPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _result;

  static const String endpoint = "http://10.0.2.2:8000/predict";

  @override
  void initState() {
    super.initState();
    _processUpload();
  }

  Future<void> _processUpload() async {
    try {
      final imageId = uuid.v4();

      // Upload image to Supabase Storage
      final imageBytes = await widget.imageFile.readAsBytes();

      await supabase.storage
          .from('plant-images')
          .uploadBinary('$imageId.jpg', imageBytes);

      // Send to backend for prediction
      var request = http.MultipartRequest("POST", Uri.parse(endpoint));
      request.files.add(
        await http.MultipartFile.fromPath("image", widget.imageFile.path),
      );

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        // Save prediction in database
        await supabase.from('Collected Data').insert({
          'id': imageId,
          'image_path': '$imageId.jpg',
          'prediction': data['prediction'],
          'confidence': data['confidence'],
          'advice': data['advice'],
        });

        setState(() {
          _result = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Server error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Something went wrong: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prediction Result")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Prediction: ${_result!["prediction"]}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Confidence: ${(_result!["confidence"] * 100).toStringAsFixed(2)}%",
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Advice:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...(_result!["advice"] as List)
                      .map((tip) => Text("• $tip"))
                      .toList(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text("Back to Home"),
                  ),
                ],
              ),
      ),
    );
  }
}
