import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/user_provider.dart';
import 'api_constants.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentPhone;
  final String currentAddress;
  final String? profilePicUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentPhone,
    required this.currentAddress,
    this.profilePicUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  final ValueNotifier<File?> _selectedImage = ValueNotifier<File?>(null);

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentName);
    emailController = TextEditingController(text: widget.currentEmail);
    phoneController = TextEditingController(text: widget.currentPhone);
    addressController = TextEditingController(text: widget.currentAddress);
  }

  String _getFullImageUrl(String path) {
    if (path.startsWith('http')) {
      return '$path?t=${DateTime.now().millisecondsSinceEpoch}';
    }
    String separator = path.startsWith('/') ? '' : '/';
    return '${ApiConstants.mediaUrl}$separator$path?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _selectedImage.value = File(pickedFile.path);
    }
  }

  Future<void> _updateProfile() async {
    final userProvider = context.read<UserProvider>();
    final result = await userProvider.updateProfile(
      nameController.text.trim(),
      emailController.text.trim(),
      phoneController.text.trim(),
      addressController.text.trim(),
      _selectedImage.value,
    );

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('changes_saved'.tr()), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else if (mounted) {
      if (result['error'] == 'network') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('network_error'.tr()), backgroundColor: Colors.orange));
      } else if (result['error'] != 'unauthorized') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('update_failed'.tr()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final bgColor = theme.scaffoldBackgroundColor;
    final secondaryColor = theme.colorScheme.surfaceContainerHighest;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    final isLoading = context.watch<UserProvider>().isLoading;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                  ValueListenableBuilder<File?>(
                    valueListenable: _selectedImage,
                    builder: (context, selectedImage, child) {
                      return CircleAvatar(
                        radius: 50,
                        backgroundColor: secondaryColor,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage)
                            : (widget.profilePicUrl != null ? NetworkImage(_getFullImageUrl(widget.profilePicUrl!)) as ImageProvider : null),
                        child: selectedImage == null && widget.profilePicUrl == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                      );
                    },
                  ),
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    _buildTextField(Icons.person_outline, 'full_name'.tr(), nameController, theme),
                    const SizedBox(height: 16),
                    _buildTextField(Icons.mail_outline, 'email_address'.tr(), emailController, theme),
                    const SizedBox(height: 16),
                    _buildTextField(Icons.phone_outlined, 'phone_number'.tr(), phoneController, theme),
                    const SizedBox(height: 16),
                    _buildTextField(Icons.location_on_outlined, 'address'.tr(), addressController, theme),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              isLoading
                  ? CircularProgressIndicator(color: primaryColor)
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            child: Text('save_changes'.tr(), style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            child: Text('cancel'.tr(), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(IconData icon, String label, TextEditingController controller, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: TextField(
            controller: controller,
            style: TextStyle(color: theme.textTheme.bodyLarge!.color),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
            ),
          ),
        ),
      ],
    );
  }
}