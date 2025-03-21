import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/attendance_service.dart';
import '../../models/geo_fence_model.dart';

class GeoFenceManagementScreen extends StatefulWidget {
  const GeoFenceManagementScreen({super.key});

  @override
  _GeoFenceManagementScreenState createState() =>
      _GeoFenceManagementScreenState();
}

class _GeoFenceManagementScreenState extends State<GeoFenceManagementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fields for adding new Geo-fences
  String _locationName = '';
  String _latitude = '';
  String _longitude = '';
  String _radius = '';

  bool _isSubmitting = false; // For indicating a geo-fence is being added
  bool _isDeleting =
      false; // For indicating a geo-fence deletion is in progress

  late Future<List<GeoFenceModel>> _geoFenceFuture;

  @override
  void initState() {
    super.initState();
    _geoFenceFuture = _loadGeoFences();
  }

  /// Loads the existing geo-fences from the attendance service.
  Future<List<GeoFenceModel>> _loadGeoFences() async {
    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);
    try {
      return await attendanceService.getGeoFences();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading geo-fences: $e');
      }
      rethrow;
    }
  }

  /// Confirms with the user whether to delete the specified geo-fence.
  Future<bool> _confirmDeletion(String fenceName) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete the geo-fence "$fenceName"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  /// Adds a new geo-fence if the form is valid, with error handling & spinner.
  Future<void> _addGeoFence() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    final double latitude = double.parse(_latitude);
    final double longitude = double.parse(_longitude);
    final double radius = double.parse(_radius);

    setState(() => _isSubmitting = true);

    try {
      final attendanceService =
          Provider.of<AttendanceService>(context, listen: false);
      await attendanceService.addGeoFence(
        GeoPoint(latitude, longitude),
        radius,
        _locationName,
      );
      _showSnackBar('Geo-fence added successfully.');
      _formKey.currentState!.reset();
      setState(() {
        _locationName = '';
        _latitude = '';
        _longitude = '';
        _radius = '';
      });
      // Reload the list of geo-fences
      _geoFenceFuture = _loadGeoFences();
    } catch (e) {
      _showSnackBar('Error adding geo-fence: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Deletes a geo-fence by ID, with confirmation and error handling.
  Future<void> _deleteGeoFence(String geoFenceId, String fenceName) async {
    final confirmed = await _confirmDeletion(fenceName);
    if (!confirmed) return;

    setState(() => _isDeleting = true);
    try {
      final attendanceService =
          Provider.of<AttendanceService>(context, listen: false);
      await attendanceService.deleteGeoFence(geoFenceId);
      _showSnackBar('Geo-fence deleted successfully.');
      // Reload the list so the deleted fence is removed
      _geoFenceFuture = _loadGeoFences();
    } catch (e) {
      _showSnackBar('Error deleting geo-fence: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We wrap the entire UI in a Stack so we can show a loading overlay
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo-fence Management'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main gradient background + content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Form to add a new geo-fence
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Text(
                              'Add New Geo-fence',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Location Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a location name';
                                }
                                return null;
                              },
                              onSaved: (value) => _locationName = value!.trim(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter latitude';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                              onSaved: (value) => _latitude = value!.trim(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter longitude';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                              onSaved: (value) => _longitude = value!.trim(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Radius (meters)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter radius';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                              onSaved: (value) => _radius = value!.trim(),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _addGeoFence,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Add Geo-fence'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Existing Geo-fences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // The list of geo-fences
                  Expanded(
                    child: FutureBuilder<List<GeoFenceModel>>(
                      future: _geoFenceFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading geo-fences: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('No geo-fences found.'),
                          );
                        } else {
                          final geoFences = snapshot.data!;
                          return ListView.builder(
                            itemCount: geoFences.length,
                            itemBuilder: (context, index) {
                              final geoFence = geoFences[index];
                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  title: Text(
                                    geoFence.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Lat: ${geoFence.location.latitude.toStringAsFixed(4)}, '
                                    'Long: ${geoFence.location.longitude.toStringAsFixed(4)}\n'
                                    'Radius: ${geoFence.radius.toInt()} meters',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: _isDeleting
                                        ? null
                                        : () => _deleteGeoFence(
                                              geoFence.id,
                                              geoFence.name,
                                            ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // If either adding or deleting is in progress, overlay a spinner
          if (_isSubmitting || _isDeleting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
