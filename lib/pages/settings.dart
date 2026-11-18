import 'package:flutter/material.dart';
import '../core/api.dart';

enum T { text, num, flag, csv, segs, multi }
const _fields = <(String, String, T)>[
  ('appName', 'App name', T.text), ('announcement', 'Announcement', T.text), ('supportEmail', 'Support email (shown in Profile)', T.text), ('supportWhatsapp', 'Support WhatsApp number with country code (e.g. 919876543210)', T.text),
  ('supportMessage', 'WhatsApp pre-filled message', T.text), ('supportHours', 'Support hours text (e.g. 10 AM - 8 PM)', T.text), ('supportLink', 'Help center link (optional)', T.text),
  ('appInfoTitle', 'App info screen title', T.text), ('appInfoText', 'App info text (shown to users)', T.multi),
  ('privacyUrl', 'Privacy policy URL', T.text), ('termsUrl', 'Terms URL', T.text), ('homeSections', 'Home sections order (announcement,banners,recent)', T.csv),
  ('scratchEnabled', 'Scratch card ON', T.flag), ('spinEnabled', 'Spin wheel ON', T.flag), ('adsEnabled', 'Watch ads ON', T.flag), ('vipEarnEnabled', 'VIP earning ON', T.flag), ('withdrawEnabled', 'Withdrawals ON', T.flag),
  ('scratchMin', 'Scratch min reward (₹)', T.num), ('scratchMax', 'Scratch max reward (₹)', T.num), ('scratchDailyLimit', 'Scratch daily limit', T.num),
  ('spinSegments', 'Spin segments amount(₹):weight, ...', T.segs), ('spinDailyLimit', 'Spin daily limit', T.num),
  ('coinsPerRupee', 'Coins per ₹1 (users see coins)', T.num), ('adRevenue', 'Revenue YOU earn per ad (₹)', T.num), ('userSharePercent', 'User share % (rest is your profit)', T.num),
  ('adsDailyLimit', 'Ads daily limit', T.num), ('adUnitId', 'AdMob rewarded unit id', T.text),
  ('vipAdRevenue', 'Revenue YOU earn per VIP ad (₹)', T.num), ('vipUserSharePercent', 'VIP user share %', T.num), ('vipDailyLimit', 'VIP ads daily limit', T.num), ('vipAdUnitId', 'AdMob VIP rewarded unit id', T.text),
  ('referralBonus', 'Referral bonus (₹)', T.num), ('vipPrice', 'VIP price', T.num), ('vipDurationDays', 'VIP duration days (0 = lifetime)', T.num),
  ('vipUpiId', 'VIP payment UPI id', T.text), ('vipQrUrl', 'VIP QR image URL', T.text),
  ('minWithdraw', 'Minimum withdrawal (₹)', T.num), ('withdrawMethods', 'Withdraw methods (comma)', T.csv),
  ('minVersion', 'Minimum version (force update)', T.text), ('latestVersion', 'Latest version', T.text),
  ('maintenance', 'Maintenance mode', T.flag), ('maintenanceMessage', 'Maintenance message', T.text),
];

const _sec = {
  'appName': 'General', 'supportEmail': 'Support (Profile screen)', 'appInfoTitle': 'App info screen', 'homeSections': 'Home screen',
  'scratchEnabled': 'Features on / off', 'scratchMin': 'Scratch card (amounts in ₹)', 'spinSegments': 'Spin wheel',
  'coinsPerRupee': 'Ads: coins and revenue share', 'vipAdRevenue': 'VIP ads: revenue share', 'referralBonus': 'Referral & VIP',
  'minWithdraw': 'Withdrawals', 'minVersion': 'App version & maintenance',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _S();
}

class _S extends State<SettingsPage> {
  final ctl = <String, TextEditingController>{}; final flags = <String, bool>{}; bool loaded = false, busy = false;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final d = await loadSettings();
    for (final f in _fields) {
      final v = d[f.$1];
      if (f.$3 == T.flag) { flags[f.$1] = v == true || (v == null && f.$1 != 'maintenance'); }
      else if (f.$3 == T.csv) { ctl[f.$1] = TextEditingController(text: v is List ? v.join(',') : ''); }
      else if (f.$3 == T.segs) { ctl[f.$1] = TextEditingController(text: v is List ? v.map((e) => '${e['amount']}:${e['weight']}').join(', ') : ''); }
      else { ctl[f.$1] = TextEditingController(text: v == null ? '' : '$v'); }
    }
    if (mounted) setState(() => loaded = true);
  }
  Future<void> save() async {
    final out = <String, dynamic>{};
    try {
      for (final f in _fields) {
        final t = ctl[f.$1]?.text.trim() ?? '';
        switch (f.$3) {
          case T.flag: out[f.$1] = flags[f.$1] ?? false;
          case T.text: out[f.$1] = t;
          case T.multi: out[f.$1] = (ctl[f.$1]?.text ?? '').trim();
          case T.num: if (t.isNotEmpty) { out[f.$1] = num.parse(t); }
          case T.csv: out[f.$1] = t.isEmpty ? <String>[] : t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          case T.segs:
            if (t.isNotEmpty) {
              out[f.$1] = t.split(',').map((e) { final p = e.trim().split(':'); return {'amount': num.parse(p[0]), 'weight': num.parse(p[1])}; }).toList();
            }
        }
      }
    } catch (_) { toast(context, 'Check number fields / segment format (amount:weight)'); return; }
    setState(() => busy = true);
    await act(context, () => call('updateSettings', {'settings': out}), 'Settings saved');
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) {
    if (!loaded) return const Loading();
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final f in _fields) ...[
        if (_sec.containsKey(f.$1)) SectionTitle(_sec[f.$1]!),
        if (f.$3 == T.flag) Card(child: SwitchListTile(title: Text(f.$2), value: flags[f.$1]!, onChanged: (v) => setState(() => flags[f.$1] = v)))
        else Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Expanded(child: TextField(controller: ctl[f.$1], minLines: f.$3 == T.multi ? 5 : 1, maxLines: f.$3 == T.multi ? 12 : 1, keyboardType: f.$3 == T.num ? TextInputType.number : (f.$3 == T.multi ? TextInputType.multiline : TextInputType.text), decoration: InputDecoration(labelText: f.$2, alignLabelWithHint: f.$3 == T.multi))),
          if (f.$1 == 'vipQrUrl') IconButton(icon: const Icon(Icons.upload), onPressed: () async {
            final u = await act2(c, () => pickAndUpload('qr')); if (u != null) setState(() => ctl['vipQrUrl']!.text = u); })])),
      ],
      const SizedBox(height: 12),
      FilledButton(onPressed: busy ? null : save, child: const Text('Save settings')),
      const SizedBox(height: 24),
    ]);
  }
}

Future<String?> act2(BuildContext c, Future<String?> Function() f) async {
  try { return await f(); } catch (e) { if (c.mounted) toast(c, e.toString()); return null; }
}

class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});
  @override
  State<NotifyPage> createState() => _N();
}

class _N extends State<NotifyPage> {
  final title = TextEditingController(), body = TextEditingController(), uids = TextEditingController();
  String target = 'all'; bool busy = false;
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
    DropdownButtonFormField<String>(value: target, decoration: const InputDecoration(labelText: 'Send to'),
      items: const [DropdownMenuItem(value: 'all', child: Text('All users')), DropdownMenuItem(value: 'vip', child: Text('VIP users')), DropdownMenuItem(value: 'selected', child: Text('Selected users'))],
      onChanged: (v) => setState(() => target = v!)),
    if (target == 'selected') Padding(padding: const EdgeInsets.only(top: 12), child: TextField(controller: uids, decoration: const InputDecoration(labelText: 'User UIDs (comma separated)'))),
    const SizedBox(height: 12), TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
    const SizedBox(height: 12), TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
    const SizedBox(height: 16),
    FilledButton.icon(icon: const Icon(Icons.send), label: const Text('Send'), onPressed: busy ? null : () async {
      setState(() => busy = true);
      await act(c, () => call('sendNotification', {'title': title.text.trim(), 'body': body.text.trim(), 'target': target,
        'uids': uids.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()}), 'Sent');
      if (mounted) setState(() => busy = false);
    }),
  ]);
}

class BannersPage extends StatelessWidget {
  const BannersPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add_photo_alternate), label: const Text('Add banner'), onPressed: () async {
      final u = await act2(c, () => pickAndUpload('banners'));
      if (u != null && c.mounted) act(c, () => pb.collection('banners').create(body: {'imageUrl': u, 'active': true}), 'Banner added');
    }),
    body: StreamBuilder<List<Map<String, dynamic>>>(stream: listStream('banners', sort: '-created', limit: 100), builder: (c, s) {
      if (!s.hasData) return const Loading();
      if (s.data!.isEmpty) return const Empty('No banners');
      return ListView(padding: const EdgeInsets.only(bottom: 90), children: [for (final m in s.data!)
        Card(child: Column(children: [
          Image.network('${m['imageUrl'] ?? ''}', height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 120)),
          Row(children: [Expanded(child: SwitchListTile(title: const Text('Active'), value: m['active'] == true, onChanged: (v) => act(c, () => pb.collection('banners').update('${m['id']}', body: {'active': v})))),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => act(c, () => pb.collection('banners').delete('${m['id']}')))])]))]);
    }));
}
