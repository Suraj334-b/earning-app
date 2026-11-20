import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ====== CHANGE THESE TWO VALUES ======
const kPbUrl = 'http://127.0.0.1:8090'; // local PocketBase (Termux on this phone). Change to your https URL when you host it.
const kGoogleWebClientId = '68828443779-9tiaoi9k0jhgtkroq59j9iauq961n8lb.apps.googleusercontent.com'; // Google Cloud "Web application" client id
// =====================================

late final PocketBase pb;

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

String get myId {
  try {
    final p = pb.authStore.token.split('.')[1];
    final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(p))));
    return j['id'] as String;
  } catch (_) {
    return '';
  }
}

Future<void> initApi() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('pb_auth_admin');
  pb = PocketBase(
    kPbUrl,
    authStore: AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth_admin', data),
      initial: (saved == null || saved.isEmpty) ? null : saved,
    ),
  );
  if (pb.authStore.isValid) {
    try {
      await pb.collection('app_users').authRefresh();
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) pb.authStore.clear();
    } catch (_) {}
  }
}

String _msg(ClientException e) {
  final m = e.response['message'];
  return (e.statusCode == 0 || m == null || '$m'.isEmpty) ? 'Network error. Try again.' : '$m';
}

Future<void> loginWithGoogle() async {
  final g = await GoogleSignIn(serverClientId: kGoogleWebClientId).signIn();
  if (g == null) return;
  final a = await g.authentication;
  if (a.idToken == null) throw ApiError('Google token missing. Check your Google client id setup.');
  try {
    final r = await pb.send('/api/earn/google-login', method: 'POST', body: {'idToken': a.idToken, 'app': 'admin'});
    pb.authStore.save(r['token'] as String, RecordModel.fromJson(Map<String, dynamic>.from(r['record'] as Map)));
  } on ClientException catch (e) {
    throw ApiError(_msg(e));
  }
}

Future<void> logout() async {
  try {
    await GoogleSignIn().signOut();
  } catch (_) {}
  pb.authStore.clear();
}

/// Role of the logged-in staff member (read fresh from the server).
Future<String> loadRole() async {
  try {
    final r = await pb.collection('app_users').getOne(myId);
    return '${r.data['role']}';
  } catch (_) {
    return 'user';
  }
}

const _routes = {
  'reviewVip': '/api/earn/admin/review-vip',
  'reviewWithdrawal': '/api/earn/admin/review-withdrawal',
  'setUserState': '/api/earn/admin/user-state',
  'adjustWallet': '/api/earn/admin/adjust-wallet',
  'updateSettings': '/api/earn/admin/settings',
  'setRole': '/api/earn/admin/set-role',
  'sendNotification': '/api/earn/admin/notify',
};

Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
  try {
    final r = await pb.send(_routes[name]!, method: 'POST', body: data ?? {});
    return Map<String, dynamic>.from(r as Map);
  } on ClientException catch (e) {
    if (e.statusCode == 401) pb.authStore.clear();
    throw ApiError(_msg(e));
  } catch (_) {
    throw ApiError('Network error. Try again.');
  }
}

Future<Map<String, dynamic>> loadStats() async {
  try {
    final r = await pb.send('/api/earn/admin/stats');
    return Map<String, dynamic>.from(r as Map);
  } on ClientException catch (e) {
    throw ApiError(_msg(e));
  }
}

const settingsId = 'appsettings0001';
Future<Map<String, dynamic>> loadSettings() async {
  final r = await pb.collection('app_settings').getOne(settingsId);
  return Map<String, dynamic>.from(jsonDecode('${r.data['data']}') as Map);
}

Map<String, dynamic> rec(RecordModel r) => {...r.data, 'id': r.id};

/// PocketBase filter string literal.
String q(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

Stream<List<Map<String, dynamic>>> listStream(String col, {String? filter, String? sort, int limit = 50}) =>
    _live<List<Map<String, dynamic>>>(col, '*', () async {
      final r = await pb.collection(col).getList(page: 1, perPage: limit, filter: filter, sort: sort);
      return r.items.map(rec).toList();
    });

Stream<Map<String, dynamic>> oneStream(String col, String id) =>
    _live<Map<String, dynamic>>(col, id, () async {
      try {
        return rec(await pb.collection(col).getOne(id));
      } on ClientException catch (e) {
        if (e.statusCode == 404 || e.statusCode == 403) return <String, dynamic>{};
        rethrow;
      }
    });

Stream<Map<String, dynamic>> firstStream(String col, String filter) =>
    _live<Map<String, dynamic>>(col, '*', () async {
      final r = await pb.collection(col).getList(page: 1, perPage: 1, filter: filter);
      return r.items.isEmpty ? <String, dynamic>{} : rec(r.items.first);
    });

Stream<T> _live<T>(String col, String topic, Future<T> Function() load) {
  late final StreamController<T> c;
  UnsubscribeFunc? unsub;
  var dead = false;
  Future<void> run() async {
    try {
      final v = await load();
      if (!c.isClosed) c.add(v);
    } catch (e) {
      if (!c.isClosed) c.addError(e);
    }
  }

  c = StreamController<T>(
    onListen: () async {
      await run();
      try {
        final u = await pb.collection(col).subscribe(topic, (_) => run());
        if (dead) {
          await u();
        } else {
          unsub = u;
        }
      } catch (e) {
        debugPrint('realtime subscribe failed: $e');
      }
    },
    onCancel: () async {
      dead = true;
      await unsub?.call();
    },
  );
  return c.stream;
}

/// Runs an action, shows success/error toast.
Future<bool> act(BuildContext c, Future<dynamic> Function() f, [String ok = 'Done']) async {
  try { await f(); if (c.mounted) toast(c, ok); return true; }
  catch (e) { if (c.mounted) toast(c, e.toString()); return false; }
}

/// Picks an image, uploads it to PocketBase (collection "uploads") and returns its public URL.
Future<String?> pickAndUpload(String folder) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (x == null) return null;
  final r = await pb.collection('uploads').create(
      body: {'folder': folder}, files: [await http.MultipartFile.fromPath('file', x.path, filename: 'img.jpg')]);
  return pb.files.getUrl(r, '${r.data['file']}').toString();
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

String money(num? v) => '₹${(v ?? 0).toStringAsFixed(2)}';

String ts(dynamic t) {
  if (t == null || '$t'.isEmpty) return '';
  final d = DateTime.tryParse('$t'.replaceFirst(' ', 'T'))?.toLocal();
  if (d == null) return '';
  final s = d.toString();
  return s.length > 16 ? s.substring(0, 16) : s;
}

const kBrand = Color(0xFF00897B);
const kBrand2 = Color(0xFF26C6DA);

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext c) => const Center(child: CircularProgressIndicator());
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: kBrand.withOpacity(0.10), shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, size: 40, color: kBrand)),
        const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)])));
}

class GradientCard extends StatelessWidget {
  final Widget child; final List<Color> colors; final EdgeInsets padding;
  const GradientCard({super.key, required this.child, this.colors = const [kBrand, kBrand2], this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext c) => Container(
      width: double.infinity, padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.30), blurRadius: 22, offset: const Offset(0, 10))]),
      child: child);
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)));
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext c) {
    final col = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(status.toUpperCase(), style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 11)));
  }
}

class Stat extends StatelessWidget {
  final String label, value; final IconData icon; final Color? color;
  const Stat(this.label, this.value, this.icon, {super.key, this.color});
  @override
  Widget build(BuildContext c) {
    final col = color ?? kBrand;
    return Card(margin: const EdgeInsets.all(5), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: col)),
      const SizedBox(height: 8),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(c).textTheme.bodySmall)])));
  }
}

Future<String?> askText(BuildContext c, String title, {String hint = ''}) {
  final t = TextEditingController();
  return showDialog<String>(context: c, builder: (_) => AlertDialog(title: Text(title),
    content: TextField(controller: t, autofocus: true, decoration: InputDecoration(hintText: hint)),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('OK'))]));
}
