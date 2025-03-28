import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stock_app/models/document_type.dart';

class DocumentVerificationPage extends ConsumerStatefulWidget {
  const DocumentVerificationPage({super.key});

  @override
  ConsumerState<DocumentVerificationPage> createState() =>
      _DocumentVerificationPageState();
}

class _DocumentVerificationPageState
    extends ConsumerState<DocumentVerificationPage> {
  DocumentType? _selectedDocType;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitForVerification() async {
    if (_selectedDocType == null || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select document type and upload a file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Implement document upload logic
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document submitted for verification'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final formContent = _buildFormContent(constraints);

            if (constraints.maxWidth > 900) {
              return Center(
                child: SizedBox(
                  height: constraints.maxHeight * 0.7,
                  width: constraints.maxWidth * 0.4,
                  child: formContent,
                ),
              );
            }
            return formContent;
          },
        ),
      ),
    );
  }

  Widget _buildFormContent(BoxConstraints constraints) {
    return Center(
      child: Container(
        decoration: constraints.maxWidth > 900
            ? BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(20),
                ),
                color: Colors.transparent,
                border: Border.all(
                  color: Colors.black26,
                  width: 2,
                ),
              )
            : null,
        child: SingleChildScrollView(
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset("assets/icons/auth.png"),
                  Text(
                    "Hope you're not a bot",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    "Please upload a government-issued proof of identity",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Gap(32),
                  DropdownButtonFormField<DocumentType>(
                    value: _selectedDocType,
                    decoration: const InputDecoration(
                      labelText: "Choose Document Type",
                    ),
                    items: DocumentType.values.map((DocumentType type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (DocumentType? newValue) {
                      setState(() {
                        _selectedDocType = newValue;
                      });
                    },
                  ),
                  Gap(32),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 100,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Gap(16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _isLoading ? null : _pickDocument,
                            icon: Icon(Icons.attach_file),
                            label: Text(_selectedFile?.name ?? "Choose File"),
                          ),
                          if (_selectedFile != null) ...[
                            Gap(8),
                            Text(
                              "Selected file: ${_selectedFile!.name}",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Gap(32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (_selectedDocType != null &&
                              _selectedFile != null &&
                              !_isLoading)
                          ? _submitForVerification
                          : null,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit for Verification"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
