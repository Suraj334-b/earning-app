import 'package:flutter/material.dart';
import '../core/api.dart';

class UsersPage extends StatefulWidget {
  final String role;
  const UsersPage({super.key, required this.role});
  @override
  State<UsersPage> createState() => _U();
}

class _U extends State<UsersPage> {
  final q0 = TextEditingController(); String term = '';
  Stream<List<Map<String, dynamic>>> stream() {
    if (term.isEmpty) return listStream('app_users', sort: '-created', limit: 30);
    if (term.contains('@')) return listStream('app_users', filter: 'email = ${q(term.toLowerCase())}', limit: 20);
    if (term.length == 15 && !term.contains(' ')) return listStream('app_users', filter: 'id = ${q(term)}', limit: 1);
    return listStream('app_users', filter: 'displayName ~ ${q(term)}', limit: 20);
  }
  @override
  Widget build(BuildContext c) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), child: TextField(controller: q0, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by user ID, email or name'),
        onSubmitted: (v) => setState(() => term = v.trim()))),
    Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: stream(), builder: (c, s) {
      if (s.hasError) return Empty('${s.error}');
      if (!s.hasData) return const Loading();
      if (s.data!.isEmpty) return const Empty('No users found');
      return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [for (final m in s.data!)
        Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: kBrand.withOpacity(0.15), backgroundImage: '${m['photoUrl'] ?? ''}' != '' ? NetworkImage('${m['photoUrl']}') : null, child: '${m['photoUrl'] ?? ''}' == '' ? const Icon(Icons.person, color: kBrand) : null),
          title: Text('${m['displayName'] ?? ''}'), subtitle: Text('${m['email']}\n${m['id']}'), isThreeLine: true,
          trailing: Wrap(spacing: 4, children: [if (m['vip'] == true) const Icon(Icons.workspace_premium, color: Colors.amber), if (m['blocked'] == true) const Icon(Icons.block, color: Colors.red)]),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => UserDetail(uid: '${m['id']}', role: widget.role)))))]);
    })),
  ]);
}

class UserDetail extends StatelessWidget {
  final String uid, role;
  const UserDetail({super.key, required this.uid, required this.role});
  Widget row(String a, String b) => ListTile(dense: true, title: Text(a), trailing: Text(b));
  @override
  Widget build(BuildContext c) {
    final canAct = role != 'support';
    return Scaffold(appBar: AppBar(title: const Text('User')), body: StreamBuilder<Map<String, dynamic>>(stream: oneStream('app_users', uid), builder: (c, us) =>
      StreamBuilder<Map<String, dynamic>>(stream: firstStream('wallets', 'user = ${q(uid)}'), builder: (c, ws) {
        if (!us.hasData || !ws.hasData) return const Loading();
        final u = us.data!, w = ws.data!;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: Column(children: [
            row('Name', '${u['displayName']}'), row('Email', '${u['email']}'), row('User ID', uid),
            row('Status', '${u['status']}${u['blocked'] == true ? ' (blocked)' : ''}'), row('VIP', u['vip'] == true ? 'Yes' : 'No'),
            row('Role', '${u['role']}'), row('Joined', ts(u['created'])), row('Referral code', '${u['referralCode']}'),
            row('Referred by', '${u['referredBy'] ?? ''}'.isEmpty ? '-' : '${u['referredBy']}')])),
          Card(child: Column(children: [
            row('Balance', money(w['balance'])), row('Pending', money(w['pending'])), row('Total earned', money(w['totalEarned'])),
            row('Referral earned', money(w['referralEarned'])), row('VIP earned', money(w['vipEarned']))])),
          if (canAct) Wrap(spacing: 8, children: [
            FilledButton.tonal(onPressed: () => act(c, () => call('setUserState', {'uid': uid, 'blocked': u['blocked'] != true}), 'Updated'), child: Text(u['blocked'] == true ? 'Unblock' : 'Block')),
            FilledButton.tonal(onPressed: () => act(c, () => call('setUserState', {'uid': uid, 'status': u['status'] == 'active' ? 'inactive' : 'active'}), 'Updated'), child: Text(u['status'] == 'active' ? 'Deactivate' : 'Activate')),
            FilledButton.tonal(onPressed: () => act(c, () => call('setUserState', {'uid': uid, 'vip': u['vip'] != true}), 'Updated'), child: Text(u['vip'] == true ? 'Remove VIP' : 'Make VIP')),
            if (role == 'super_admin') FilledButton(onPressed: () async {
              final a = await askText(c, 'Adjust amount (negative to deduct)'); if (a == null || a.isEmpty) return;
              if (!c.mounted) return; final r = await askText(c, 'Reason (required)'); if (r == null || r.isEmpty) return;
              if (!c.mounted) return; act(c, () => call('adjustWallet', {'uid': uid, 'amount': double.tryParse(a) ?? 0, 'reason': r}), 'Wallet adjusted');
            }, child: const Text('Adjust wallet')),
          ]),
          const Padding(padding: EdgeInsets.only(top: 16), child: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold))),
          StreamBuilder<List<Map<String, dynamic>>>(stream: listStream('transactions', filter: 'user = ${q(uid)}', sort: '-created', limit: 30), builder: (c, s) {
            final d = s.data ?? <Map<String, dynamic>>[]; if (d.isEmpty) return const Empty('No transactions');
            return Column(children: [for (final m in d)
              ListTile(dense: true, title: Text('${m['type']}'), subtitle: Text(ts(m['created'])), trailing: Text(money(m['amount'] as num?)))]);
          }),
          const Padding(padding: EdgeInsets.only(top: 16), child: Text('Referrals made', style: TextStyle(fontWeight: FontWeight.bold))),
          StreamBuilder<List<Map<String, dynamic>>>(stream: listStream('referrals', filter: 'referrer = ${q(uid)}', sort: '-created', limit: 30), builder: (c, s) {
            final d = s.data ?? <Map<String, dynamic>>[]; if (d.isEmpty) return const Empty('No referrals');
            return Column(children: [for (final m in d)
              ListTile(dense: true, title: Text('${m['referred']}'), subtitle: Text('${m['status']}'), trailing: Text(money(m['bonus'] as num?)))]);
          }),
        ]);
      })));
  }
}
