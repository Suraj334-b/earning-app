import 'package:flutter/material.dart';
import '../core/api.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _D();
}

class _D extends State<DashboardPage> {
  late Future<Map<String, dynamic>> f = load();
  Future<Map<String, dynamic>> load() async {
    final d = await loadStats();
    d['days'] = (d['days'] as List).map((e) => (e as num).toInt()).toList();
    return d;
  }
  @override
  Widget build(BuildContext c) => RefreshIndicator(onRefresh: () async { setState(() => f = load()); await f; }, child: FutureBuilder<Map<String, dynamic>>(future: f, builder: (c, s) {
    if (s.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${s.error}'))]);
    if (!s.hasData) return const Loading();
    final d = s.data!, days = (d['days'] as List<int>), mx = days.fold<int>(1, (a, b) => b > a ? b : a);
    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
      GradientCard(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total users', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          Text('${d['users']}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          Text('+${d['monthUsers']} this month', style: const TextStyle(color: Colors.white70)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Needs action', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          Text('${(d['pendingWd'] as num).toInt() + (d['pendingVip'] as num).toInt()}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          const Text('pending requests', style: TextStyle(color: Colors.white70)),
        ]),
      ])),
      const SizedBox(height: 8),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.55, children: [
        Stat('Active users', '${d['active']}', Icons.person, color: Colors.blue),
        Stat('VIP users', '${d['vip']}', Icons.workspace_premium, color: Colors.amber.shade700),
        Stat('Total deposits (VIP)', money(d['deposits']), Icons.south_west, color: Colors.green),
        Stat('Total withdrawn', money(d['paid']), Icons.north_east, color: Colors.red),
        Stat('Pending withdrawals', '${d['pendingWd']} (${money(d['pendingWdAmt'])})', Icons.hourglass_bottom, color: Colors.orange),
        Stat('Pending VIP requests', '${d['pendingVip']}', Icons.pending_actions, color: Colors.deepPurple),
        Stat('Verified ad rewards', '${d['rewards']} (${money(d['rewardsAmt'])})', Icons.verified, color: Colors.teal),
        Stat('Ad revenue (estimated)', money(d['revenueTotal']), Icons.ads_click, color: Colors.indigo),
        Stat('Your profit (estimated)', money(d['ownerProfit']), Icons.savings, color: Colors.green.shade700),
      ]),
      const SectionTitle('New users, last 7 days'),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 140, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var k = 0; k < days.length; k++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${days[k]}', style: Theme.of(c).textTheme.labelSmall),
          const SizedBox(height: 4),
          Container(height: 8 + 80 * days[k] / mx, decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBrand, kBrand2], begin: Alignment.bottomCenter, end: Alignment.topCenter), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 6),
          Text(wd[now.subtract(Duration(days: days.length - 1 - k)).weekday - 1], style: Theme.of(c).textTheme.labelSmall)])))])))),
      const SizedBox(height: 8),
      Text('Ad revenue is visible in your AdMob dashboard.', textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
    ]);
  }));
}
