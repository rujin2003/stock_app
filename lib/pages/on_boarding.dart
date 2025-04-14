import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/layouts/mobile_layout.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';

// Supabase client instance
final supabaseClient = Supabase.instance.client;

// User data provider

final userDataProvider = StateNotifierProvider<UserDataNotifier, Map<String, dynamic>>((ref) {
  return UserDataNotifier();
});

class UserDataNotifier extends StateNotifier<Map<String, dynamic>> {
  UserDataNotifier() : super({});

  void updateField(String field, dynamic value) {
    state = {...state, field: value};
  }

  void setUserData(Map<String, dynamic> userData) {
    state = userData;
  }
}

// Form validation provider
final formValidationProvider = StateProvider<Map<String, bool>>((ref) {
  return {
    'personalDetails': false,
    'contactDetails': false,
    'addressDetails': false,
    'documentUpload': false,
  };
});

class OnBoarding extends ConsumerStatefulWidget {
  const OnBoarding({super.key});
  
  @override
  ConsumerState<OnBoarding> createState() => _OnBoardingState();
}

class _OnBoardingState extends ConsumerState<OnBoarding> {
  // Controllers for form fields
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthdayController = TextEditingController();
  final emailController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final zipcodeController = TextEditingController();

  String? selectedCountry;
  String? selectedGender;
  String? selectedDocumentType1;
  String? selectedDocumentType2;
  File? documentFile1;
  File? documentFile2;
  String? documentFileName1;
  String? documentFileName2;
  
  final pageController = PageController();
  int currentPage = 0;
  bool isSubmitting = false;
  String? errorMessage;
  
  // Country codes map
  final Map<String, String> countryCodes = {
    'India': '+91',
    'USA': '+1',
    'Canada': '+1',
    'UK': '+44',
    'Australia': '+61',
    'Germany': '+49',
    'France': '+33',
    'Japan': '+81',
  };

  @override
  void initState() {
    super.initState();
    loadUserData();
    
    // Add listeners to all text controllers to trigger validation
    firstNameController.addListener(_onFormFieldChanged);
    lastNameController.addListener(_onFormFieldChanged);
    birthdayController.addListener(_onFormFieldChanged);
    emailController.addListener(_onFormFieldChanged);
    mobileController.addListener(_onFormFieldChanged);
    addressController.addListener(_onFormFieldChanged);
    cityController.addListener(_onFormFieldChanged);
    zipcodeController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    // This forces the UI to rebuild and re-evaluate the button state
    setState(() {});
  }

  @override
  void dispose() {
    // Remove listeners from controllers
    firstNameController.removeListener(_onFormFieldChanged);
    lastNameController.removeListener(_onFormFieldChanged);
    birthdayController.removeListener(_onFormFieldChanged);
    emailController.removeListener(_onFormFieldChanged);
    mobileController.removeListener(_onFormFieldChanged);
    addressController.removeListener(_onFormFieldChanged);
    cityController.removeListener(_onFormFieldChanged);
    zipcodeController.removeListener(_onFormFieldChanged);
    
    // Dispose controllers
    firstNameController.dispose();
    lastNameController.dispose();
    birthdayController.dispose();
    emailController.dispose();
    mobileController.dispose();
    addressController.dispose();
    cityController.dispose();
    zipcodeController.dispose();
    pageController.dispose();
    super.dispose();
  }

  // Load user data if it exists
  Future<void> loadUserData() async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      final response = await supabaseClient
          .from('appusers')
          .select()
          .eq('user_id', userId)
          .single();

      setState(() {
        firstNameController.text = response['first_name'] ?? '';
        lastNameController.text = response['last_name'] ?? '';
        birthdayController.text = response['birthday'] ?? '';
        emailController.text = response['email'] ?? '';
        mobileController.text = response['number'] ?? '';
        addressController.text = response['address'] ?? '';
        cityController.text = response['city'] ?? '';
        zipcodeController.text = response['zipcode'] ?? '';
        selectedCountry = response['country'];
        selectedGender = response['gender'];
        selectedDocumentType1 = response['document1_type'];
        selectedDocumentType2 = response['document2_type'];
        
        // Load document info if exists
        if (response['document1'] != null) {
          documentFileName1 = response['document1'];
        }
        
        if (response['document2'] != null) {
          documentFileName2 = response['document2'];
        }
      });
        } catch (e) {
      // User data might not exist yet
      print('Error loading user data: $e');
    }
  }
  
  // Send email to backend
  Future<void> sendEmailToBackend(String email, Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-backend-url.com/api/onboarding-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userData': userData,
        }),
      );
      
      if (response.statusCode != 200) {
        print('Error sending email: ${response.body}');
      }
    } catch (e) {
      print('Error sending email: $e');
    }
  }
  
  // Validate postal code based on country
  bool isValidPostalCode(String postalCode, String? country) {
    if (postalCode.isEmpty) return false;
    
    switch (country) {
      case 'India':
        // Indian postal code (PIN) is 6 digits
        return RegExp(r'^[1-9][0-9]{5}$').hasMatch(postalCode);
      case 'USA':
        // US ZIP code is 5 digits or 5+4
        return RegExp(r'^\d{5}(-\d{4})?$').hasMatch(postalCode);
      case 'Canada':
        // Canadian postal code is A1A 1A1 format
        return RegExp(r'^[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d$').hasMatch(postalCode);
      case 'UK':
        // UK postal code is complex, but this is a simplified check
        return RegExp(r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$').hasMatch(postalCode);
      default:
        // For other countries, just check if it's not empty
        return postalCode.isNotEmpty;
    }
  }
  
  Future<void> submitKYC() async {
    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });
    
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Validate postal code
      if (!isValidPostalCode(zipcodeController.text, selectedCountry)) {
        throw Exception('Invalid postal code for ${selectedCountry ?? "selected country"}');
      }
      
      // Validate phone number length
      if (mobileController.text.length > 10) {
        throw Exception('Phone number should not exceed 10 digits');
      }
      
      // Validate email
      if (emailController.text.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
        throw Exception('Please enter a valid email address');
      }

      // Check if user already has an account balance
      final existingBalance = await supabaseClient
          .from('account_balances')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      // Prepare user data
      final userData = {
        'user_id': userId,
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
        'birthday': birthdayController.text,
        'email': emailController.text,
        'country': selectedCountry,
        'gender': selectedGender,
        'number': mobileController.text,
        'address': addressController.text,
        'city': cityController.text,
        'zipcode': zipcodeController.text,
        'document1_type': selectedDocumentType1,
        'document2_type': selectedDocumentType2,
        'is_kyc_verified': false,
        'registration_date': DateTime.now().toIso8601String(),
        'account_balance': existingBalance?['balance'] ?? 0, // Use existing balance if available
        'active_trades': 0, // Set initial active trades to 0
      };

      // Upload documents if selected
      if (documentFile1 != null) {
        final fileExt = path.extension(documentFile1!.path).replaceFirst('.', '');
        final fileName = '${userId}_doc1_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'user_documents/$fileName';
        
        // Upload to userkycdoc bucket
        await supabaseClient.storage
            .from('userkycdoc')
            .upload(filePath, documentFile1!);
            
        // Add document URL to userData
        userData['document1'] = "https://vlppfasnfmxqbyijcjyx.supabase.co/storage/v1/object/public/userkycdoc/$filePath";
      }
      
      if (documentFile2 != null) {
        final fileExt = path.extension(documentFile2!.path).replaceFirst('.', '');
        final fileName = '${userId}_doc2_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'user_documents/$fileName';
        
        // Upload to userkycdoc bucket
        await supabaseClient.storage
            .from('userkycdoc')
            .upload(filePath, documentFile2!);
            
        // Add document URL to userData
        userData['document2'] = "https://vlppfasnfmxqbyijcjyx.supabase.co/storage/v1/object/public/userkycdoc/$filePath";
      }

      // Check if user exists, then update or insert
      final userExists = await supabaseClient
          .from('appusers')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (userExists != null) {
        await supabaseClient
            .from('appusers')
            .update(userData)
            .eq('user_id', userId);
      } else {
        await supabaseClient
            .from('appusers')
            .insert(userData);
      }
      
      // Send email to backend
      final userEmail = supabaseClient.auth.currentUser?.email;
      if (userEmail != null) {
        await sendEmailToBackend(userEmail, userData);
      }

      // Navigate to KYC verification status page using GoRouter
      if (mounted) {
        context.go('/kyc_verification_status');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error submitting KYC: ${e.toString()}';
      });
      print('Error in KYC submission: $e');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Future<void> pickDocument(int documentNumber) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        if (pickedFile.path != null) {
          setState(() {
            if (documentNumber == 1) {
              documentFile1 = File(pickedFile.path!);
              documentFileName1 = pickedFile.name;
            } else {
              documentFile2 = File(pickedFile.path!);
              documentFileName2 = pickedFile.name;
            }
          });
        }
      }
    } catch (e) {
      print('Error picking file: $e');
      setState(() {
        errorMessage = 'Failed to pick document: ${e.toString()}';
      });
    }
  }

  void nextPage() {
    if (currentPage < 3) {
      pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        currentPage++;
      });
    } else {
      submitKYC();
    }
  }

  void previousPage() {
    if (currentPage > 0) {
      pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        currentPage--;
      });
    }
  }

  bool validateCurrentPage() {
    switch (currentPage) {
      case 0: // Personal Details
        return firstNameController.text.isNotEmpty && 
               lastNameController.text.isNotEmpty && 
               birthdayController.text.isNotEmpty;
      case 1: // Contact Details
        return selectedCountry != null && 
               selectedGender != null && 
               emailController.text.isNotEmpty &&
               RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text) &&
               mobileController.text.isNotEmpty;
      case 2: // Address Details
        return addressController.text.trim().isNotEmpty && 
               cityController.text.trim().isNotEmpty && 
               zipcodeController.text.trim().isNotEmpty &&
               isValidPostalCode(zipcodeController.text, selectedCountry);
      case 3: // Document Upload
        return selectedDocumentType1 != null && 
               selectedDocumentType2 != null && 
               documentFile1 != null && 
               documentFile2 != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KYC Verification'),
        leading: currentPage > 0 
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: previousPage,
              )
            : null,
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authStateNotifierProvider.notifier).signOut();
              if (mounted) {
                context.go('/');
              }
            },
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= currentPage 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                      ),
                    ) 
                    
                  );
                  }),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Page content
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    buildPersonalDetailsPage(),
                    buildContactDetailsPage(),
                    buildAddressDetailsPage(),
                    buildDocumentUploadPage(),
                  ],
                ),
              ),
              
              // Error message
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Next/Submit button
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSubmitting || !validateCurrentPage() 
                      ? null 
                      : nextPage,
                  child: isSubmitting
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          currentPage == 3 ? "SUBMIT KYC" : "CONTINUE",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPersonalDetailsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please provide your basic personal details',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: "First Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: "Last Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          TextFormField(
            controller: birthdayController,
            decoration: InputDecoration(
              labelText: "Date of Birth",
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  birthdayController.text = 
                      "${date.day}/${date.month}/${date.year}";
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your date of birth';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget buildContactDetailsPage() {
    final countries = ["USA", "Canada", "UK", "Australia", "India", "Germany", "France", "Japan"];
    final genders = ["Male", "Female", "Other", "Prefer not to say"];
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please provide your contact details',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          DropdownButtonFormField<String>(
            value: selectedCountry,
            decoration: InputDecoration(
              labelText: "Country",
              border: OutlineInputBorder(),
            ),
            items: countries.map((country) => 
              DropdownMenuItem(
                value: country,
                child: Text(country),
              )
            ).toList(),
            onChanged: (value) {
              setState(() {
                selectedCountry = value;
                // If India is selected, add the country code to the mobile number
                if (value == 'India' && !mobileController.text.startsWith('+91')) {
                  mobileController.text = '+91 ${mobileController.text}';
                } else if (value != 'India' && mobileController.text.startsWith('+91 ')) {
                  // Remove the country code if India is not selected
                  mobileController.text = mobileController.text.substring(4);
                }
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your country';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: InputDecoration(
              labelText: "Gender",
              border: OutlineInputBorder(),
            ),
            items: genders.map((gender) => 
              DropdownMenuItem(
                value: gender,
                child: Text(gender),
              )
            ).toList(),
            onChanged: (value) {
              setState(() {
                selectedGender = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your gender';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: "Email Address",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              
              return null;
            },
          ),
          SizedBox(height: 16),
          
          TextFormField(
            controller: mobileController,
            decoration: InputDecoration(
              labelText: "Mobile Number",
              border: OutlineInputBorder(),
              prefixText: selectedCountry == 'India' ? '+91 ' : '+',
              helperText: 'Maximum 10 digits',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your mobile number';
              }
              
              // Remove country code and spaces for validation
              String cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');
              
              if (cleanNumber.length > 10) {
                return 'Phone number should not exceed 10 digits';
              }
              
              if (!RegExp(r'^[0-9]+$').hasMatch(cleanNumber)) {
                return 'Please enter a valid number';
              }
              
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget buildAddressDetailsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Address Information',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please provide your current address',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          TextFormField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: "Street Address",
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your address';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: "City",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your city';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: zipcodeController,
                  decoration: InputDecoration(
                    labelText: "Postal/ZIP Code",
                    border: OutlineInputBorder(),
                    helperText: selectedCountry == 'India' 
                        ? '6-digit PIN code' 
                        : 'Enter valid postal code',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your postal code';
                    }
                    
                    if (!isValidPostalCode(value, selectedCountry)) {
                      return 'Invalid postal code for ${selectedCountry ?? "selected country"}';
                    }
                    
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDocumentUploadPage() {
    final documentTypes = ["Passport", "Driving License", "National ID", "Residence Permit", "Utility Bill", "Bank Statement", "Tax Return", "Employment Contract"];
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Verification',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Upload two different documents to verify your identity',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          
          // First Document Type Selection
          Text(
            'Document 1 Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          DropdownButtonFormField<String>(
            value: selectedDocumentType1,
            decoration: InputDecoration(
              labelText: "Select Document Type",
              border: OutlineInputBorder(),
            ),
            items: documentTypes.map((type) => 
              DropdownMenuItem(
                value: type,
                child: Text(type),
              )
            ).toList(),
            onChanged: (value) {
              setState(() {
                selectedDocumentType1 = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a document type';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // First Document Upload
          Text(
            'Upload Document 1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          if (documentFile1 != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, size: 40, color: Colors.blue),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documentFileName1 ?? 'Document',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${(documentFile1!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        documentFile1 = null;
                        documentFileName1 = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => pickDocument(1),
              child: Text('UPLOAD DIFFERENT DOCUMENT'),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => pickDocument(1),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Tap to upload document 1',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Supports: JPG, PNG, PDF\nMax size: 5MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          SizedBox(height: 24),
          
          // Second Document Type Selection
          Text(
            'Document 2 Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          DropdownButtonFormField<String>(
            value: selectedDocumentType2,
            decoration: InputDecoration(
              labelText: "Select Document Type",
              border: OutlineInputBorder(),
            ),
            items: documentTypes.map((type) => 
              DropdownMenuItem(
                value: type,
                child: Text(type),
              )
            ).toList(),
            onChanged: (value) {
              setState(() {
                selectedDocumentType2 = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a document type';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // Second Document Upload
          Text(
            'Upload Document 2',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          if (documentFile2 != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, size: 40, color: Colors.blue),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documentFileName2 ?? 'Document',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${(documentFile2!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        documentFile2 = null;
                        documentFileName2 = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => pickDocument(2),
              child: Text('UPLOAD DIFFERENT DOCUMENT'),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => pickDocument(2),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Tap to upload document 2',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Supports: JPG, PNG, PDF\nMax size: 5MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Document Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Documents must be valid and not expired\n'
                  '• All information must be clearly visible\n'
                  '• Full document must be captured\n'
                  '• No glare or reflections on the document\n'
                  '• File size must not exceed 5MB\n'
                  '• You must upload two different types of documents',
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}