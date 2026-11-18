import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';

class RequestsPage extends StatefulWidget {
  final bool canAct;
  const RequestsPage({super.key, required this.canAct});
  @override
  State<RequestsPage> createState() => _R();
}

class _R extends State<RequestsPage> {
  String status = 'pending';
  @override
  Widget build(BuildContext c) => DefaultTabController(length: 2, child: Column(children: [
    const TabBar(tabs: [Tab(text: 'VIP payments'), Tab(text: 'Withdrawals')]),
    Padding(padding: const EdgeInsets.all(8), child: Wrap(spacing: 8, children: [
      for (final s in ['pending', 'approved', 'rejected']) ChoiceChip(label: Text(s), selected: status == s, onSelected: (_) => setState(() => status = s))])),
    Expanded(child: TabBarView(children: [_vip(), _wd()])),
  ]));

  Widget _list(String col, Widget Function(Map<String, dynamic>) tile) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: listStream(col, filter: 'status = "$status"', sort: '-created', limit: 50),
    builder: (c, s) {
      if (s.hasError) return Empty('${s.error}');
      if (!s.hasData) return const Loading();
      if (s.data!.isEmpty) return Empty('No $status requests');
      return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [for (final d in s.data!) tile(d)]);
    });

  Widget _actions(bool show, VoidCallback ok, VoidCallback no) => show
      ? Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          Expanded(child: FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Approve'), onPressed: ok)),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.tonalIcon(icon: const Icon(Icons.close), label: const Text('Reject'), onPressed: no)),
        ]))
      : const SizedBox();

  Widget _head(IconData i, Color col, String title, String sub, String st) => Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(14)), child: Icon(i, color: col)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(sub, style: const TextStyle(fontSize: 12)),
        ])),
        StatusChip(st),
      ]);

  Widget _vip() => _list('vip_payment_requests', (m) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _head(Icons.workspace_premium, Colors.amber.shade700, money(m['amount']), ts(m['created']), status),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('UTR: ${m['utr']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.copy, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: '${m['utr']}'))),
      ]),
      Text('User: ${m['user']}', style: Theme.of(context).textTheme.bodySmall),
      _actions(widget.canAct && status == 'pending',
        () async { if (await _confirm(context, 'Approve VIP? Confirm the payment really arrived in your bank for UTR ${m['utr']}.')) { if (context.mounted) act(context, () => call('reviewVip', {'requestId': m['id'], 'approve': true}), 'Approved'); } },
        () async { if (await _confirm(context, 'Reject this request?')) { if (context.mounted) act(context, () => call('reviewVip', {'requestId': m['id'], 'approve': false}), 'Rejected'); } }),
    ])));
  });

  Widget _wd() => _list('withdrawal_requests', (m) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _head(Icons.north_east, Colors.red, money(m['amount']), '${m['method']} • ${ts(m['created'])}', status),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('${m['details']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.copy, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: '${m['details']}'))),
      ]),
      Text('User: ${m['user']}${'${m['paymentRef'] ?? ''}'.isNotEmpty ? '\nRef: ${m['paymentRef']}' : ''}', style: Theme.of(context).textTheme.bodySmall),
      _actions(widget.canAct && status == 'pending',
        () async {
          final ref = await askText(context, 'Payment reference / UTR you paid with'); if (ref == null || ref.isEmpty) return;
          if (context.mounted) act(context, () => call('reviewWithdrawal', {'id': m['id'], 'approve': true, 'paymentRef': ref}), 'Marked paid'); },
        () async { if (await _confirm(context, 'Reject and refund to wallet?')) { if (context.mounted) act(context, () => call('reviewWithdrawal', {'id': m['id'], 'approve': false}), 'Rejected & refunded'); } }),
    ])));
  });
}

Future<bool> _confirm(BuildContext c, String msg) async => (await showDialog<bool>(context: c, builder: (_) => AlertDialog(content: Text(msg), actions: [
  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes'))]))) ?? false;
