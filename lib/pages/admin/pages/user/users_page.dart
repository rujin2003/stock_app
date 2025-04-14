import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/admin_service/user/user_service.dart' as user_service;
import 'package:stock_app/pages/admin/models/user_model.dart' as app_model;
import 'package:stock_app/pages/admin/admin_service/user/user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:stock_app/pages/admin/admin_service/user/user_provider.dart';

class UserFilter {
  bool showVerified = true;
  bool showUnverified = true;
  bool showWithActiveTrades = false;
  String searchQuery = '';
  
  List<app_model.User> apply(List<app_model.User> users) {
    return users.where((user) {
      final matchVerified = (showVerified && user.isVerified) || (showUnverified && !user.isVerified);
      final matchActive = !showWithActiveTrades || (user.activeTrades ?? 0) > 0;
      final matchSearch = searchQuery.isEmpty ||
          user.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(searchQuery.toLowerCase());
      return matchVerified && matchActive && matchSearch;
    }).toList();
  }
}

class UsersPage extends ConsumerStatefulWidget {
  final bool  isfromDashboard;
const UsersPage({
  super.key,
  this.isfromDashboard = false,
});
  
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> with SingleTickerProviderStateMixin {
  final UserFilter filter = UserFilter();
  final userServiceProvider = Provider<user_service.UserService>((ref) => user_service.UserService());
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _searchController.addListener(_handleSearchChange);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
  }
   void _refreshData() {
    // Refresh the users provider
    ref.refresh(user_service.usersProvider);
    
    // Show a brief refresh indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing user data...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0: // All
            filter.showVerified = true;
            filter.showUnverified = true;
            break;
          case 1: // Verified
            filter.showVerified = true;
            filter.showUnverified = false;
            break;
          case 2: // Unverified
            filter.showVerified = false;
            filter.showUnverified = true;
            break;
        }
      });
    }
  }
  
  void _handleSearchChange() {
    setState(() {
      filter.searchQuery = _searchController.text;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(user_service.usersProvider);
    
    return Scaffold(
     
      body: Column(
        children: [
          widget.isfromDashboard ? const SizedBox(height: 0) : AppBar(
            title: const Text('Users'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _showFilterDialog(context),
              ),
            ],
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All Users'),
              Tab(text: 'Verified'),
              Tab(text: 'Unverified'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allUsers) {
                final filteredUsers = filter.apply(allUsers);
                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('No users match the current filters'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    return ref.refresh(user_service.usersProvider);
                  },
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _showUserDetails(user,context),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey.shade200,
                                      child: const Icon(Icons.person, size: 36, color: Colors.deepPurple),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.name,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (user.isVerified)
                                                const Icon(Icons.verified, color: Colors.teal, size: 16),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.email,
                                            style: Theme.of(context).textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Joined: ${_formatDate(user.registrationDate)}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    if (user.isVerified)
                                      _buildInfoColumn(
                                        context,
                                        title: 'Balance',
                                        value: '\$${(user.accountBalance ?? 0.0).toStringAsFixed(2)}',
                                        icon: Icons.account_balance_wallet,
                                      )
                                    else
                                      _buildInfoColumn(
                                        context,
                                        title: 'Verification',
                                        value: 'Required',
                                        icon: Icons.gpp_maybe,
                                        valueColor: Colors.red,
                                      ),
                                    _buildInfoColumn(
                                      context,
                                      title: 'Active Trades',
                                      value: (user.activeTrades ?? 0).toString(),
                                      icon: Icons.trending_up,
                                    ),
                                    _buildInfoColumn(
                                      context,
                                      title: 'Status',
                                      value: user.isVerified ? 'Verified' : 'Pending',
                                      icon: user.isVerified ? Icons.check_circle : Icons.pending,
                                      valueColor: user.isVerified ? Colors.green : Colors.orange,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('View Details'),
                                      onPressed: () => _showUserDetails(user,context),
                                    ),
                                    if (!user.isVerified)
                                      TextButton.icon(
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Verify'),
                                        onPressed: () => _confirmVerification(user,context),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    floatingActionButton:Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Refresh button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              onTap: _refreshData,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Icon(Icons.refresh, color: Colors.white),
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withOpacity(0.5),
          ),
          // Filter button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              onTap: () => _showFilterDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Icon(Icons.filter_list, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _confirmVerification(app_model.User user, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Verification'),
        content: Text('Are you sure you want to verify ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final userService = ref.read(userServiceProvider);
                await userService.verifyUser(user.id);
                
                // Close loading dialog
                if (mounted) {
                  Navigator.pop(context);
                }
                
                // Refresh the data
                _refreshData();
                
                // Show success message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.name} has been verified successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Close loading dialog if open
                if (mounted) {
                  Navigator.pop(context);
                }
                
                // Show error message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error verifying user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  // Function to download and view a document
  Future<void> _viewDocument(String documentUrl, String documentName, BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Downloading document...'),
                ],
              ),
            ),
          );
        },
      );

      // Check if it's a PDF
      final isPdf = documentUrl.toLowerCase().endsWith('.pdf');
      
      if (isPdf) {
        // Download and open PDF
        final response = await http.get(Uri.parse(documentUrl));
        final bytes = response.bodyBytes;
        
        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$documentName');
        
        // Write the file
        await file.writeAsBytes(bytes);
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Show PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(documentName),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    onPressed: () async {
                      // Implement save to downloads functionality
                      final downloadsDir = await getExternalStorageDirectory();
                      final downloadFile = File('${downloadsDir?.path}/$documentName');
                      await downloadFile.writeAsBytes(bytes);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloaded to: ${downloadsDir?.path}/$documentName')),
                      );
                    },
                  ),
                ],
              ),
              body: PDFView(
                filePath: file.path,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
              ),
            ),
          ),
        );
      } else {
        // Close loading dialog
        Navigator.pop(context);
        
        // For other document types, open in browser/default app
        final url = Uri.parse(documentUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the document')),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  void _showUserDetails(app_model.User user,BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(Icons.person, size: 36, color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              if (user.isVerified)
                                const Icon(Icons.verified, color: Colors.teal, size: 20),
                            ],
                          ),
                          Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Text('Account Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDetailRow(context, label: 'User ID', value: user.id),
                _buildDetailRow(context, label: 'Registration Date', value: _formatDate(user.registrationDate)),
                _buildDetailRow(context, label: 'Account Balance', value: '\$${(user.accountBalance ?? 0.0).toStringAsFixed(2)}'),
                _buildDetailRow(context, label: 'Active Trades', value: (user.activeTrades ?? 0).toString()),
                _buildDetailRow(
                  context,
                  label: 'Verification Status',
                  value: user.isVerified ? 'Verified' : 'Pending',
                  valueColor: user.isVerified ? Colors.green : Colors.orange,
                ),
                ...[
                const SizedBox(height: 20),
                Text('KYC Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDetailRow(context, label: 'First Name', value: user.firstName ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Last Name', value: user.lastName ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Birth Date', value: user.birthday ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Gender', value: user.gender ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Country', value: user.country ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Phone Number', value: user.number ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Address', value: user.address ?? 'Unavailable'),
                _buildDetailRow(context, label: 'City', value: user.city ?? 'Unavailable'),
                _buildDetailRow(context, label: 'Zip Code', value: user.zipcode ?? 'Unavailable'),
                
                // Document section - Added for document viewing
                const SizedBox(height: 20),
                Text('Documents',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Check if user has documents
                if (user.document1 != null && user.document1!.isNotEmpty)
                  _buildDocumentRow(
                    context,
                    label: 'Document 1',
                    value: user.document1Type ?? 'Unavailable',
                    documentUrl: user.document1!,
                    onViewPressed: () => _viewDocument(user.document1!, '${user.name}_Document1.pdf', context),
                  )
                else
                  _buildDetailRow(context, label: 'Document 1', value: 'No document uploaded'),
                  
                if (user.document2 != null && user.document2!.isNotEmpty)
                  _buildDocumentRow(
                    context,
                    label: 'Document 2',
                    value: user.document2Type ?? 'Unavailable',
                    documentUrl: user.document2!,
                    onViewPressed: () => _viewDocument(user.document2!, '${user.name}_Document2.pdf', context),
                  )
                else
                  _buildDetailRow(context, label: 'Document 2', value: 'No document uploaded'),

             
              
              ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!user.isVerified)
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Verify User'),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmVerification(user,context);
                          },
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // New widget for document rows with view button
  Widget _buildDocumentRow(
    BuildContext context, {
    required String label,
    required String value,
    required String documentUrl,
    required VoidCallback onViewPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.blue),
            tooltip: 'View Document',
            onPressed: onViewPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool showVerified = filter.showVerified;
        bool showUnverified = filter.showUnverified;
        bool showWithActiveTrades = filter.showWithActiveTrades;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter Users'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Verified Users'),
                    value: showVerified,
                    onChanged: (value) => setStateDialog(() => showVerified = value ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Unverified Users'),
                    value: showUnverified,
                    onChanged: (value) => setStateDialog(() => showUnverified = value ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('With Active Trades'),
                    value: showWithActiveTrades,
                    onChanged: (value) => setStateDialog(() => showWithActiveTrades = value ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      filter.showVerified = showVerified;
                      filter.showUnverified = showUnverified;
                      filter.showWithActiveTrades = showWithActiveTrades;
                      // Sync tab controller with filter settings
                      if (showVerified && showUnverified) {
                        _tabController.animateTo(0);
                      } else if (showVerified) {
                        _tabController.animateTo(1);
                      } else if (showUnverified) {
                        _tabController.animateTo(2);
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}