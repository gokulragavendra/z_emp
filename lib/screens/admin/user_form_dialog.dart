import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../services/user_service.dart';
import '../../services/organisation_service.dart';

class UserFormDialog extends StatefulWidget {
  final UserModel? user;

  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late UserService userService;
  late OrganisationService organisationService;

  /// Manages the spinner while we save the user data.
  bool _isSaving = false;

  /// Manages the spinner while we load the branches.
  bool _isLoadingBranches = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'Sales Staff';
  bool _isActive = true;
  DateTime? _dob;
  DateTime? _joiningDate;
  String? _branchId;
  List<BranchModel> _branches = [];

  @override
  void initState() {
    super.initState();
    userService = Provider.of<UserService>(context, listen: false);
    organisationService =
        Provider.of<OrganisationService>(context, listen: false);

    _loadBranches();

    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _emailController.text = widget.user!.email;
      _mobileController.text = widget.user!.mobileNumber;
      _addressController.text = widget.user!.address;
      _role = widget.user!.role;
      _isActive = widget.user!.isActive;
      _dob = widget.user!.dob.toDate();
      _joiningDate = widget.user!.joiningDate.toDate();
      _branchId = widget.user!.branchId;
    }
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);
    try {
      _branches = await organisationService.getBranches();
      // If no branch is selected and branches exist, default to the first
      if (_branchId == null && _branches.isNotEmpty) {
        _branchId = _branches.first.branchId;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading branches: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBranches = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Asks the user for confirmation before saving the user data
  Future<void> _confirmSave() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(widget.user == null ? 'Add User' : 'Save Changes'),
          content: Text(
            widget.user == null
                ? 'Are you sure you want to add this new user?'
                : 'Are you sure you want to save these changes?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _saveUserImplementation();
    }
  }

  /// Actually saves the user (adding or updating)
  Future<void> _saveUserImplementation() async {
    if (_isSaving) return; // Prevent double-click

    setState(() => _isSaving = true);

    final user = UserModel(
      userId: widget.user?.userId ?? '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      address: _addressController.text.trim(),
      role: _role,
      isActive: _isActive,
      dob: Timestamp.fromDate(_dob ?? DateTime.now()),
      joiningDate: Timestamp.fromDate(_joiningDate ?? DateTime.now()),
      branchId: _branchId ?? '',
      profilePhotoUrl: '',
    );

    try {
      if (widget.user == null) {
        // Adding new user
        await userService.addUser(user, _passwordController.text.trim());
        Navigator.pop(context, true); // Indicate success
      } else {
        // Updating existing user
        await userService.updateUser(user);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Add User' : 'Edit User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_isLoadingBranches)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter email'
                    : null,
              ),
              const SizedBox(height: 16),
              // Password (only for new users)
              if (widget.user == null) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter password'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              // Mobile Number
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.length != 10) {
                    return 'Mobile number must be 10 digits';
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                    return 'Invalid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Role
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                ),
                value: _role,
                items: ['Admin', 'Manager', 'Sales Staff', 'Measurement Staff']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select a role' : null,
              ),
              const SizedBox(height: 16),
              // Branch
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Branch *',
                  border: OutlineInputBorder(),
                ),
                value: _branchId,
                items: _branches.map((branch) {
                  return DropdownMenuItem(
                    value: branch.branchId,
                    child: Text(branch.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _branchId = value;
                  });
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select a branch'
                    : null,
              ),
              const SizedBox(height: 16),
              // Active Status
              SwitchListTile(
                title: const Text('Active Status'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              // DOB
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _dob ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() => _dob = pickedDate);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dob != null
                        ? '${_dob!.toLocal()}'.split(' ')[0]
                        : 'Select Date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Joining Date
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _joiningDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() => _joiningDate = pickedDate);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Joining Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _joiningDate != null
                        ? '${_joiningDate!.toLocal()}'.split(' ')[0]
                        : 'Select Date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _confirmSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
