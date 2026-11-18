import 'package:flutter/material.dart';
import '../core/api.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _St();
}

class _St extends State<StaffPage> {
  final uid = TextEditingController(); String role = 'admin';
  @override
  Widget build(BuildContext c) => DefaultTabController(length: 2, child: Column(children: [
    const TabBar(tabs: [Tab(text: 'Staff'), Tab(text: 'Activity logs')]),
    Expanded(child: TabBarView(children: [
      ListView(padding: const EdgeInsets.all(12), children: [
        TextField(controller: uid, decoration: const InputDecoration(labelText: 'User ID (user must have logged in once)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: role, items: [for (final r in ['super_admin', 'admin', 'support', 'user']) DropdownMenuItem(value: r, child: Text(r))], onChanged: (v) => role = v!, decoration: const InputDecoration(labelText: 'Role (user = remove access)')),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => act(c, () => call('setRole', {'uid': uid.text.trim(), 'role': role}), 'Role updated (user must re-login)'), child: const Text('Assign role')),
        const Divider(height: 32),
        StreamBuilder<List<Map<String, dynamic>>>(stream: listStream('app_users', filter: 'role != "user"', limit: 100), builder: (c, s) => Column(children: [
          for (final m in s.data ?? <Map<String, dynamic>>[]) Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.security)), title: Text('${m['displayName']}'), subtitle: Text('${m['email']}\n${m['id']}'), isThreeLine: true, trailing: Text('${m['role'] ?? ''}'.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800, color: kBrand))))])),
      ]),
      StreamBuilder<List<Map<String, dynamic>>>(stream: listStream('admin_activity_logs', sort: '-created', limit: 80), builder: (c, s) {
        if (s.hasError) return Empty('${s.error}');
        if (!s.hasData) return const Loading();
        if (s.data!.isEmpty) return const Empty('No activity yet');
        return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [for (final m in s.data!)
          Card(child: ListTile(leading: const Icon(Icons.history), title: Text('${m['action']} → ${m['target'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('by ${m['by']} • ${ts(m['created'])}${'${m['details'] ?? ''}'.isNotEmpty ? '\n${m['details']}' : ''}')))]);
      }),
    ])),
  ]));
}
