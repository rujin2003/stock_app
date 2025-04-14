import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/pages/admin/admin_service/user/user_service.dart';
import 'package:stock_app/pages/admin/models/trade_model.dart';
import 'package:stock_app/pages/admin/models/user_model.dart';
import 'package:stock_app/pages/admin/pages/trade/trade_detail_page.dart';

class UserTradesPage extends ConsumerStatefulWidget {
  final String userId;

  const UserTradesPage({super.key, required this.userId});

  @override
  ConsumerState<UserTradesPage> createState() => _UserTradesPageState();
}

class _UserTradesPageState extends ConsumerState<UserTradesPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<Trade> _trades = [];
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialTrades();
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _loadMoreTrades();
    }
  }
  
  Future<void> _loadInitialTrades() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tradesAsync = await ref.read(userTradesProvider(widget.userId).future);
      setState(() {
        _trades = tradesAsync.take(_pageSize).toList();
        _hasMore = tradesAsync.length > _pageSize;
        _page = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreTrades() async {
    if (!_hasMore || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tradesAsync = await ref.read(userTradesProvider(widget.userId).future);
      final nextBatch = tradesAsync.skip(_page * _pageSize).take(_pageSize).toList();
      
      setState(() {
        if (nextBatch.isNotEmpty) {
          _trades.addAll(nextBatch);
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
    await ref.refresh(userTradesProvider(widget.userId).future);
    _loadInitialTrades();
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
      body: _trades.isEmpty && _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildTradeList(context),
    );
  }

  Widget _buildTradeList(BuildContext context) {
    if (_trades.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No trades found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This user has no trading history',
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
        itemCount: _trades.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _trades.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final trade = _trades[index];
          return _TradeCard(trade: trade);
        },
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  final Trade trade;

  const _TradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isProfit = trade.profit != null && trade.profit! >= 0;
    final profitColor = isProfit ? Colors.green : Colors.red;

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
                builder: (context) => TradeDetailPage(tradeId: trade.id),
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
                    _TradeTypeIndicator(type: trade.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trade.symbolName} (${trade.symbolCode})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${trade.type.name.toUpperCase()} • ${trade.volume} @ ${trade.entryPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (trade.profit != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: profitColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isProfit ? '+' : ''}${trade.profit!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: profitColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[200]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TradeInfoItem(
                      icon: Icons.leaderboard,
                      label: '${trade.leverage}x',
                    ),
                    _TradeInfoItem(
                      icon: Icons.calendar_today,
                      label: DateFormat('MMM dd, yyyy').format(trade.openTime),
                    ),
                    _TradeInfoItem(
                      icon: Icons.circle,
                      label: trade.status.name.toUpperCase(),
                      iconColor: _getStatusColor(trade.status),
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

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.open:
        return Colors.blue;
      case TradeStatus.closed:
        return Colors.green;
      case TradeStatus.pending:
        return Colors.orange;
      case TradeStatus.cancelled:
        return Colors.red;
    }
  }
}

class _TradeTypeIndicator extends StatelessWidget {
  final TradeType type;

  const _TradeTypeIndicator({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: type == TradeType.buy
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          type == TradeType.buy ? Icons.trending_up : Icons.trending_down,
          color: type == TradeType.buy ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

class _TradeInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _TradeInfoItem({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
} 