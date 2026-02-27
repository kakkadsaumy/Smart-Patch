import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SmartPatchApp());
}

class SmartPatchApp extends StatelessWidget {
  const SmartPatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE6F2E6), // light cream green
        primaryColor: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, // green buttons
            foregroundColor: Colors.white, // white text
            minimumSize: const Size(double.infinity, 50), // full width
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

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
                "Detect tomato leaf diseases instantly.",
                style: TextStyle(fontSize: 16),
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
    _uploadImage();
  }

  Future<void> _uploadImage() async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse(endpoint));
      request.files.add(
        await http.MultipartFile.fromPath("image", widget.imageFile.path),
      );

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
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
        _error = "Connection failed. Make sure backend is running.";
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _uploadImage,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_result != null) ...[
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
                ],
              ),
      ),
    );
  }
}
