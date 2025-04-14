// trade_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/pages/admin/admin_service/trade/trade_service.dart';
import 'package:stock_app/pages/admin/admin_service/user/user_service.dart' as user_service;
import 'package:stock_app/pages/admin/models/user_model.dart' as app_model;
import 'package:stock_app/pages/admin/pages/trade/user_trades_page.dart';

import '../../models/trade_model.dart';
import 'trade_detail_page.dart';




class TradeListPage extends ConsumerStatefulWidget {
  const TradeListPage({super.key});

  @override
  ConsumerState<TradeListPage> createState() => _TradeListPageState();
}

class _TradeListPageState extends ConsumerState<TradeListPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<app_model.User> _users = [];
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialUsers();
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _loadMoreUsers();
    }
  }
  
  Future<void> _loadInitialUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final usersAsync = await ref.read(user_service.usersProvider.future);
      setState(() {
        _users = usersAsync.take(_pageSize).toList();
        _hasMore = usersAsync.length > _pageSize;
        _page = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreUsers() async {
    if (!_hasMore || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final usersAsync = await ref.read(user_service.usersProvider.future);
      final nextBatch = usersAsync.skip(_page * _pageSize).take(_pageSize).toList();
      
      setState(() {
        if (nextBatch.isNotEmpty) {
          _users.addAll(nextBatch);
          _page++;
        }
        _hasMore = nextBatch.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _refresh() async {
    await ref.refresh(user_service.usersProvider.future);
    _loadInitialUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
      body: _users.isEmpty && _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildUserList(context),
    );
  }

  Widget _buildUserList(BuildContext context) {
    if (_users.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final user = _users[index];
          return _UserCard(user: user);
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final app_model.User user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserTradesPage(userId: user.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoColumn(
                      context,
                      title: 'Balance',
                      value: '\$${(user.accountBalance ?? 0.0).toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
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
              ],
            ),
          ),
        ),
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
}
