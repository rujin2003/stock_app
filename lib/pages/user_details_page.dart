import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/models/user_data.dart';
import 'package:stock_app/providers/auth_provider.dart';

enum UserDetailsStep {
  basicInfo('We need some details',
      'This is for a meet and greet between us and you'),
  contact('We need some details',
      'This is for a meet and greet between us and you'),
  address('We need some details',
      'This is for a meet and greet between us and you');

  final String title;
  final String subtitle;
  const UserDetailsStep(this.title, this.subtitle);
}

class UserDetailsPage extends ConsumerStatefulWidget {
  const UserDetailsPage({super.key});

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCountry;
  String? _selectedGender;

  final List<String> _countries = [
    'United States',
    'Canada',
    'India',
    'UK',
    'Australia'
  ];
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

  UserDetailsStep _currentStep = UserDetailsStep.basicInfo;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveUserDetails() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final currentUser = ref.read(authProvider);
      if (currentUser == null) return;

      final userData = UserData(
        id: currentUser.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        birthDate: _selectedDate!,
        country: _selectedCountry!,
        gender: _selectedGender!,
        mobile: _mobileController.text,
        address: _addressController.text,
        city: _cityController.text,
        zipCode: _zipCodeController.text,
      );

      try {
        // await ref
        //     .read(authProvider.notifier)
        //     ._authService
        //     .saveUserData(userData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to home or next screen
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
      }
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: "First Name"),
                validator: (value) =>
                    value?.isEmpty ?? true ? "Required" : null,
              ),
            ),
            Gap(16),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: "Last Name"),
                validator: (value) =>
                    value?.isEmpty ?? true ? "Required" : null,
              ),
            ),
          ],
        ),
        Gap(16),
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: "Birthday",
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _selectedDate == null
                  ? "Select Date"
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
            ),
          ),
        ),
        Gap(16),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: InputDecoration(labelText: "Gender"),
          items: _genders.map((String gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
          validator: (value) => value == null ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextFormField(
          controller: _mobileController,
          decoration: InputDecoration(
            labelText: "Mobile Number",
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) => value?.isEmpty ?? true ? "Required" : null,
        ),
        Gap(16),
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          decoration: InputDecoration(labelText: "Country"),
          items: _countries.map((String country) {
            return DropdownMenuItem(
              value: country,
              child: Text(country),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedCountry = newValue;
            });
          },
          validator: (value) => value == null ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: "Address",
            prefixIcon: Icon(Icons.location_on),
          ),
          maxLines: 2,
          validator: (value) => value?.isEmpty ?? true ? "Required" : null,
        ),
        Gap(16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: InputDecoration(labelText: "City"),
                validator: (value) =>
                    value?.isEmpty ?? true ? "Required" : null,
              ),
            ),
            Gap(16),
            Expanded(
              child: TextFormField(
                controller: _zipCodeController,
                decoration: InputDecoration(labelText: "Zip Code"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value?.isEmpty ?? true ? "Required" : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case UserDetailsStep.basicInfo:
        return _buildBasicInfoStep();
      case UserDetailsStep.contact:
        return _buildContactStep();
      case UserDetailsStep.address:
        return _buildAddressStep();
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case UserDetailsStep.basicInfo:
        return _firstNameController.text.isNotEmpty &&
            _lastNameController.text.isNotEmpty &&
            _selectedDate != null &&
            _selectedGender != null;
      case UserDetailsStep.contact:
        return _mobileController.text.isNotEmpty && _selectedCountry != null;
      case UserDetailsStep.address:
        return _addressController.text.isNotEmpty &&
            _cityController.text.isNotEmpty &&
            _zipCodeController.text.isNotEmpty;
    }
  }

  void _nextStep() {
    if (_canProceed()) {
      setState(() {
        switch (_currentStep) {
          case UserDetailsStep.basicInfo:
            _currentStep = UserDetailsStep.contact;
            break;
          case UserDetailsStep.contact:
            _currentStep = UserDetailsStep.address;
            break;
          case UserDetailsStep.address:
            _saveUserDetails();
            break;
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case UserDetailsStep.contact:
          _currentStep = UserDetailsStep.basicInfo;
          break;
        case UserDetailsStep.address:
          _currentStep = UserDetailsStep.contact;
          break;
        case UserDetailsStep.basicInfo:
          break;
      }
    });
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
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset("assets/icons/auth.png"),
                  Text(
                    _currentStep.title,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    _currentStep.subtitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Gap(32),
                  _buildCurrentStep(),
                  Gap(32),
                  Row(
                    children: [
                      if (_currentStep != UserDetailsStep.basicInfo)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            child: Text("Back"),
                          ),
                        ),
                      if (_currentStep != UserDetailsStep.basicInfo) Gap(16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _canProceed() ? _nextStep : null,
                          child: Text(
                            _currentStep == UserDetailsStep.address
                                ? "Submit"
                                : "Continue",
                          ),
                        ),
                      ),
                    ],
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
