import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'shift_page.dart';

// SS OIL: sabit tek kirmizi tema; eski altin/koyu palet kaldirildi.
void main()=>runApp(const OilApp());
num number(dynamic v)=>num.tryParse('$v')??0;
String money(dynamic n)=>number(n).toStringAsFixed(2).replaceAll('.',',');
String day(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
Map<String,dynamic> map(dynamic x)=>x is Map?Map<String,dynamic>.from(x):{};
List<dynamic> list(dynamic x)=>x is List?x:[];
class OilApp extends StatefulWidget {const OilApp({super.key}); @override State<OilApp> createState()=>_OilAppState();}
class _OilAppState extends State<OilApp> {
 static const red = Color(0xffcb101b);
 @override Widget build(BuildContext context) {
  return MaterialApp(
   debugShowCheckedModeBanner:false,
   title:'SS OIL',
   theme:ThemeData(
    useMaterial3:true,
    brightness:Brightness.light,
    scaffoldBackgroundColor:Colors.white,
    primaryColor:red,
    colorScheme:ColorScheme.fromSeed(seedColor:red,brightness:Brightness.light).copyWith(primary:red,secondary:red,onPrimary:Colors.white),
    cardColor:const Color(0xfffafafa),
    outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:red,side:const BorderSide(color:red),textStyle:const TextStyle(fontWeight:FontWeight.w600))),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:red,foregroundColor:Colors.white)),
    dividerColor:const Color(0xffdddddd),
    iconTheme:const IconThemeData(color:red),
    navigationBarTheme:NavigationBarThemeData(indicatorColor:red.withValues(alpha:0.16),labelTextStyle:const WidgetStatePropertyAll(TextStyle(color:Colors.black))),
    cardTheme:CardThemeData(color:const Color(0xfffafafa),shape:RoundedRectangleBorder(side:BorderSide(color:red.withValues(alpha:0.25)),borderRadius:BorderRadius.circular(18))),
    inputDecorationTheme:InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
    appBarTheme:const AppBarTheme(backgroundColor:red,foregroundColor:Colors.white),
   ),
   home:OilHome(themeIndex:2,onThemeChanged:(_){ }),
  );
 }
}
class OilHome extends StatefulWidget {final int themeIndex; final ValueChanged<int> onThemeChanged; const OilHome({super.key,required this.themeIndex,required this.onThemeChanged}); @override State<OilHome> createState()=>_OilHomeState();}
class _OilHomeState extends State<OilHome> {
 final FlutterSecureStorage secureStore=const FlutterSecureStorage();
 SharedPreferences? prefs; int page=0; bool busy=false; String message='', source='Çevrimdışı';
 String local='http://192.168.100.13:8767',cloud='',token='',coffeeUrl='',fuelIds='',supabaseUrl='',supabaseKey='',cloudStatus='Test edilmedi',supabaseEmail='',supabasePassword='',supabaseAccessToken=''; int cloudRevision=0; bool cloudAuthBusy=false;
 List<Map<String,dynamic>> products=[]; Map<String,dynamic> kasa={};
 Map<String,dynamic> base={},previousSales={},daily={},photos={},suppliers={},supplierOf={},minimum={},orders={},labels={},orderUnits={},discrepancies={},barcodeErrors={};
 DateTime selected=DateTime.now(); bool followToday=true;
 Timer? syncTimer; Timer? sharedTimer; bool refreshingReadOnly=false; bool syncing=false; bool manualSyncing=false; String cloudError=''; String sharedSyncStatus='Henüz kontrol edilmedi'; DateTime? lastSharedSync; int syncRevision=0; List<dynamic> pending=[]; Map<String,dynamic> tracked={};
 Map<String,dynamic> kasaArchive={}, fuelPrices={}, historicalFuelStock={}; DateTime? lastHistoryAudit; bool historyAuditBusy=false;
 Map<String,dynamic> get sharedData=>{'labels':labels,'orders':orders,'suppliers':suppliers,'supplierOf':supplierOf,'minimum':minimum,'discrepancies':discrepancies,'orderUnits':orderUnits,'barcodeErrors':barcodeErrors};
 @override void initState(){super.initState();load();}
 @override void dispose(){syncTimer?.cancel();sharedTimer?.cancel();super.dispose();}
 Future<void> load()async{prefs=await SharedPreferences.getInstance();supabasePassword=await secureStore.read(key:'ssoil_supabase_password')??''; if(!mounted)return;setState((){local=prefs!.getString('local')??local;cloud=prefs!.getString('cloud')??'';supabaseUrl=prefs!.getString('supabaseUrl')??'';supabaseKey=prefs!.getString('supabaseKey')??'';supabaseEmail=prefs!.getString('supabaseEmail')??'';cloudRevision=prefs!.getInt('cloudRevision')??0;token=prefs!.getString('token')??'';coffeeUrl=prefs!.getString('coffee')??'';fuelIds=prefs!.getString('fuelIds')??'';products=list(jsonDecode(prefs!.getString('products')??'[]')).map((e)=>map(e)).toList();base=map(jsonDecode(prefs!.getString('base')??'{}'));previousSales=map(jsonDecode(prefs!.getString('previousSales')??'{}'));daily=map(jsonDecode(prefs!.getString('daily')??'{}'));photos=map(jsonDecode(prefs!.getString('photos')??'{}'));suppliers=map(jsonDecode(prefs!.getString('suppliers')??'{}'));supplierOf=map(jsonDecode(prefs!.getString('supplierOf')??'{}'));minimum=map(jsonDecode(prefs!.getString('minimum')??'{}'));orders=map(jsonDecode(prefs!.getString('orders')??'{}'));labels=map(jsonDecode(prefs!.getString('labels')??'{}'));orderUnits=map(jsonDecode(prefs!.getString('orderUnits')??'{}'));discrepancies=map(jsonDecode(prefs!.getString('discrepancies')??'{}'));barcodeErrors=map(jsonDecode(prefs!.getString('barcodeErrors')??'{}'));kasaArchive=map(jsonDecode(prefs!.getString('ssoilKasaArchiveV1')??'{}'));fuelPrices=map(jsonDecode(prefs!.getString('ssoilFuelPricesV1')??'{}'));kasa=map(kasaArchive[day(selected)]);});syncRevision=prefs!.getInt('syncRevision')??0;pending=list(jsonDecode(prefs!.getString('syncPending')??'[]'));tracked=map(jsonDecode(prefs!.getString('syncTracked')??'{}'));syncTimer=Timer.periodic(const Duration(seconds:3),(_){if(followToday&&day(selected)!=day(DateTime.now())){setState((){selected=DateTime.now();kasa={};});}refreshReadOnly();});sharedTimer=Timer.periodic(const Duration(seconds:3),(_){if(mounted)syncShared();});syncShared();refreshReadOnly();auditKasaHistory();fetchFuelPrices();fetchHistoricalFuelStock();}
 Future<void> save()async{final p=prefs;if(p==null)return;for(final e in <String,dynamic>{'local':local,'cloud':cloud,'supabaseUrl':supabaseUrl,'supabaseKey':supabaseKey,'supabaseEmail':supabaseEmail,'token':token,'coffee':coffeeUrl,'fuelIds':fuelIds,'products':products,'base':base,'previousSales':previousSales,'daily':daily,'photos':photos,'suppliers':suppliers,'supplierOf':supplierOf,'minimum':minimum,'orders':orders,'labels':labels,'orderUnits':orderUnits,'discrepancies':discrepancies,'barcodeErrors':barcodeErrors}.entries){await p.setString(e.key,e.value is String?e.value:jsonEncode(e.value));}await queueSharedChanges();await secureStore.write(key:'ssoil_supabase_password',value:supabasePassword);syncShared();}
 Future<void> queueSharedChanges()async{
  for(final entry in sharedData.entries){
   final old=map(tracked[entry.key]); final current=map(entry.value);
   for(final key in {...old.keys,...current.keys}){
    if(jsonEncode(old[key])==jsonEncode(current[key]))continue;
    // Replace unsent edits for the same record; preserve the stable ID once sent.
    final existing=pending.indexWhere((x)=>x['section']==entry.key&&'${x['key']}'==key&&x['cloudSent']!=true);
    if(existing>=0){pending[existing]['value']=current[key];}
    else{pending.add({'section':entry.key,'key':key,'value':current[key],'event_id':'${DateTime.now().microsecondsSinceEpoch}_${pending.length}_${entry.key}_$key'});}
   }
  }
  tracked={for(final e in sharedData.entries)e.key:Map<String,dynamic>.from(e.value)};
  await prefs?.setString('syncTracked',jsonEncode(tracked));
  await prefs?.setString('syncPending',jsonEncode(pending));
 }
 Future<bool> cloudLogin()async{
  if(supabaseUrl.trim().isEmpty||supabaseKey.trim().isEmpty||supabaseEmail.trim().isEmpty||supabasePassword.isEmpty)return false;
  if(cloudAuthBusy)return false;
  cloudAuthBusy=true;
  try{
   final r=await http.post(Uri.parse('${supabaseUrl.trim().replaceAll(RegExp(r"/+$"),"")}/auth/v1/token?grant_type=password'),headers:{'apikey':supabaseKey.trim(),'Content-Type':'application/json'},body:jsonEncode({'email':supabaseEmail.trim(),'password':supabasePassword})).timeout(const Duration(seconds:7));
   if(r.statusCode!=200){cloudError='Giriş HTTP ${r.statusCode}: ${r.body}';return false;}
   await secureStore.write(key:'ssoil_supabase_password',value:supabasePassword);
   supabaseAccessToken='${map(jsonDecode(r.body))['access_token']??''}';
   return supabaseAccessToken.isNotEmpty;
  }catch(e){cloudError='Giriş bağlantı hatası: $e';return false;}finally{cloudAuthBusy=false;}
 }
 Future<http.Response?> shiftRequest(String method,String path,{Object? body,String? prefer})async{
  // Only Vardiya uses this isolated LAN-first route; other modules unchanged.
  final base=local.trim().replaceAll(RegExp(r'/+$'),'');
  if(base.startsWith('http')){
   try{
    final pcUri=Uri.parse(base);
    final uri=pcUri.replace(path:'/vardiya/$path');
    final req=http.Request(method,uri);
    req.headers['Content-Type']='application/json';
    if(token.isNotEmpty)req.headers['X-SSOIL-Token']=token;
    if(body!=null)req.body=jsonEncode(body);
    final client=http.Client();
    try{
     final stream=await client.send(req).timeout(const Duration(seconds:2));
     final response=await http.Response.fromStream(stream);
     if(response.statusCode>=200&&response.statusCode<300)return response;
    }finally{client.close();}
   }catch(_){}
  }
  return cloudRequest(method,path,body:body,prefer:prefer);
 }
 Future<http.Response?> cloudRequest(String method,String path,{Object? body,String? prefer})async{
  if(supabaseAccessToken.isEmpty&&!await cloudLogin()){if(cloudError.isEmpty)cloudError='Supabase giriş bilgileri eksik veya oturum açılamadı';return null;}
  final url='${supabaseUrl.trim().replaceAll(RegExp(r"/+$"),"")}/rest/v1/$path';
  // Use the standard HTTP client; refresh expired auth once.
  for(var attempt=0;attempt<2;attempt++){
   try{
    final headers={'apikey':supabaseKey.trim(),'Authorization':'Bearer $supabaseAccessToken','Content-Type':'application/json','Prefer':prefer??'resolution=ignore-duplicates,return=representation'};
    final req=http.Request(method,Uri.parse(url));req.headers.addAll(headers);if(body!=null)req.body=jsonEncode(body);
    final client=http.Client();
    try{final stream=await client.send(req).timeout(const Duration(seconds:6));final r=await http.Response.fromStream(stream);if((r.statusCode==401||r.statusCode==403)&&attempt==0){supabaseAccessToken='';if(await cloudLogin())continue;}if(r.statusCode>=400)cloudError='${method} ${path.split('?').first}: HTTP ${r.statusCode} ${r.body}';else cloudError='';return r;}finally{client.close();}
   }catch(e){cloudError='${method} bağlantı hatası: $e';return null;}
  }
  return null;
 }
 Future<bool> cloudPush(Map<String,dynamic> event)async{
  final r=await cloudRequest('POST','ssoil_events?on_conflict=event_id',body:[{'event_id':event['event_id'],'section':event['section'],'item_key':event['key'],'value':event['value']}]);
  return r!=null&&(r.statusCode==200||r.statusCode==201);
 }
 Future<Map<String,dynamic>?> cloudRead(String route)async{
  String table='';
  if(route.startsWith('/snapshot'))table='ssoil_snapshots?select=data&kind=eq.products&limit=1';
  else if(route.startsWith('/kasa')){
    final requested=Uri.parse('http://localhost$route').queryParameters['date']??day(DateTime.now());
    table='ssoil_snapshots?select=data&kind=eq.kasa%3A$requested&limit=1';
  }
  else if(route.startsWith('/daily-sales'))table='ssoil_snapshots?select=data&kind=eq.daily-sales&limit=1';
  else if(route.startsWith('/sales'))table='ssoil_snapshots?select=data&kind=eq.sales&limit=1';
  else return null;
  final r=await cloudRequest('GET',table);
  if(r?.statusCode!=200)return null;
  final rows=list(jsonDecode(r!.body));if(rows.isEmpty)return null;
  return map(map(rows.first)['data']);
 }
 Future<Map<String,dynamic>?> readAuthoritativeState(bool pcOk)async{
  if(pcOk){
   try{return await api('/shared-state');}catch(_){}
  }
  final r=await cloudRequest('GET','ssoil_snapshots?select=data&kind=eq.shared-state&limit=1');
  if(r?.statusCode!=200)return null;
  final rows=list(jsonDecode(r!.body));
  if(rows.isEmpty)return null;
  return map(map(rows.first)['data']);
 }
 Future<void> syncShared()async{
  if(syncing||prefs==null)return;
  syncing=true;
  try{
   bool pcOk=false;
   try{
    final r=await http.get(Uri.parse('${local.replaceAll(RegExp(r"/+$"),"")}/health')).timeout(const Duration(seconds:2));
    pcOk=r.statusCode==200;
   }catch(_){}
   // Offline operations always go up before an authoritative download.
   // Keep each operation ID stable across retries and route changes.
   // Pending operations are never overwritten by the 3-second snapshot.
   // An operation has one stable event_id for all three verified attempts.
   bool rollback=false;
   for(final original in List<dynamic>.from(pending)){
    final e=original as Map<String,dynamic>;
    bool applied=false;
    bool verifiedFailure=false;
    if(pcOk){
     final result=await apiPost('/shared',e);
     applied=result!=null && result.containsKey('revision') && !result.containsKey('error');
     // A reachable PC that explicitly fails an operation counts as a trial.
     verifiedFailure=!applied && result!=null;
    }else{
     if(e['cloudSent']!=true){
      if(!await cloudPush(e))continue;
      e['cloudSent']=true;
      await prefs!.setString('syncPending',jsonEncode(pending));
     }
     // No ssoil_acks or new sync tables. The PC-owned snapshot is the ACK.
     // Compare the exact key/value including deletions (null means absent).
     final canonical=await readAuthoritativeState(false);
     if(canonical!=null){
      final state=map(canonical['state']);
      final section=map(state['${e['section']}']);
      final key='${e['key']}';
      final expected=e['value'];
      applied=expected==null ? !section.containsKey(key)
          : section.containsKey(key)&&jsonEncode(section[key])==jsonEncode(expected);
     }
     // A stale snapshot is NOT a verified failure. Keep the operation pending.

    }
    if(applied){
     pending.remove(original);
     await prefs!.setString('syncPending',jsonEncode(pending));
     continue;
    }
    if(verifiedFailure){
     e['attempts']=(number(e['attempts']).toInt()+1);
     if(number(e['attempts'])>=3){
      pending.remove(original);
      rollback=true;
     }
     await prefs!.setString('syncPending',jsonEncode(pending));
    }
    // Do not let one stalled record block all the others.
    continue;
   }
   // Download canonical data even when some local operations remain pending.
   // Overlay pending local edits only for their own section/key.

   final snapshot=await readAuthoritativeState(pcOk);
   if(snapshot==null){
    if(mounted)setState(()=>sharedSyncStatus='PC güncel kayıtlarına ulaşılamadı');
    return;
   }
   final state=map(snapshot['state']);
   for(final entry in sharedData.entries){
    final authoritative=map(state[entry.key]);
    for(final item in pending){
     final e=map(item);
     if(e['section']!=entry.key)continue;
     final key='${e['key']}';
     if(e['value']==null){authoritative.remove(key);}else{authoritative[key]=e['value'];}
    }
    entry.value..clear()..addAll(authoritative);
   }
   syncRevision=number(snapshot['revision']).toInt();
   await prefs!.setInt('syncRevision',syncRevision);
   tracked={for(final e in sharedData.entries)e.key:Map<String,dynamic>.from(e.value)};
   await prefs!.setString('syncTracked',jsonEncode(tracked));
   for(final e in sharedData.entries){await prefs!.setString(e.key,jsonEncode(e.value));}
   if(mounted)setState((){lastSharedSync=DateTime.now();sharedSyncStatus=rollback?'3 başarısız deneme: PC kayıtları geri yüklendi':(pcOk?'PC güncel kayıtları alındı':'Supabase üzerinden PC kayıtları alındı');});
  }catch(e){if(mounted)setState(()=>sharedSyncStatus='Eşitleme hatası: $e');}
  finally{syncing=false;}
 }
 Future<void> syncAllManually() async {
  if(manualSyncing){notice('Eşitleme sürüyor');return;}
  if(syncing){notice('Otomatik eşitleme sürüyor, birkaç saniye sonra tekrar basın');return;}
  if(!mounted)return;
  setState(()=>manualSyncing=true);
  try{
   await queueSharedChanges();
   await syncShared();
   notice('Kontrol tamamlandı. Bekleyen: ${pending.length}. $sharedSyncStatus');
  }catch(e){notice('Eşitleme hatası: $e');}
  finally{if(mounted)setState(()=>manualSyncing=false);}
 }
 Future<void> syncCloudManually() async {
  if(manualSyncing||syncing){notice('Eşitleme sürüyor, tekrar deneyin');return;}
  setState(()=>manualSyncing=true);
  try{
   await queueSharedChanges();
   // Force a fresh Supabase login, without touching PC, Kasa or stock.
   supabaseAccessToken='';
   final ok=await cloudLogin();
   if(!ok){notice('Supabase giriş hatası: $cloudError');return;}
   await syncShared();
   notice('Supabase: $sharedSyncStatus. Bekleyen: ${pending.length}');
  }catch(e){notice('Supabase hatası: $e');}
  finally{if(mounted)setState(()=>manualSyncing=false);}
 }
 Future<Map<String,dynamic>?> apiPost(String route,Map<String,dynamic> payload)async{
  for(final address in [local,cloud]){
   if(address.trim().isEmpty)continue;
   try{
    final r=await http.post(Uri.parse('${address.replaceAll(RegExp(r"/$"),'')}$route'),headers:{'X-SSOIL-Token':token,'Content-Type':'application/json'},body:jsonEncode(payload)).timeout(const Duration(seconds:5));
    if(r.statusCode==200)return map(jsonDecode(utf8.decode(r.bodyBytes)));if(r.statusCode>=400&&r.statusCode<500&&r.statusCode!=408&&r.statusCode!=429)return {'error':'HTTP ${r.statusCode}'};
   }catch(_){ }
  }
  return null;
 }
 Future<Map<String,dynamic>> api(String route)async{for(final entry in [('Yerel ağ',local),('Bulut',cloud)]){if(entry.$2.trim().isEmpty)continue;try{final r=await http.get(Uri.parse('${entry.$2.replaceAll(RegExp(r"/$"),'')}$route'),headers:{'X-SSOIL-Token':token}).timeout(const Duration(seconds:5));if(r.statusCode==200){if(mounted && source!=entry.$1){if(page==0)setState(()=>source=entry.$1);else source=entry.$1;}return map(jsonDecode(utf8.decode(r.bodyBytes)));}if(r.statusCode==401)throw Exception('Yetkilendirme hatası'); if(r.statusCode>=400)throw Exception('HTTP ${r.statusCode}: ${r.body}');}catch(_){}}final cached=await cloudRead(route);if(cached!=null){if(mounted && source!='Supabase'){if(page==0)setState(()=>source='Supabase');else source='Supabase';}return cached;}throw Exception('Yerel sunucu ve yapılandırılmış bulut erişilemiyor');}
 void notice(String s){if(!mounted)return;setState(()=>message=s);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 // Read-only periodic refresh. Do not change stock baselines, sales counters or Kasa calculations.
  // Independently poll each read-only feed so slow endpoints do not block the others.
  Future<void> refreshReadOnly() async {
    if (refreshingReadOnly || prefs == null || !mounted) return;
    refreshingReadOnly = true;
    try {
      await Future.wait<void>([
        () async {
          try {
            final requestedDay = day(selected);
            final response = await api('/kasa?date=$requestedDay');
            if ('${response['date']}' == requestedDay) await rememberKasa(response);
            if (mounted && day(selected) == requestedDay && '${response['date']}' == requestedDay && jsonEncode(kasa) != jsonEncode(response)) { if (page == 1) {setState(() => kasa = response);} else {kasa = response;} }
          } catch (_) {}
        }(),
        () async {
          try {
            final central = await api('/daily-sales');
            final incomingDaily = map(central['daily']);
            if (!mounted) return;
            if (jsonEncode(daily) != jsonEncode(incomingDaily)) { if (page == 4 || page == 5) {setState(() => daily = incomingDaily);} else {daily = incomingDaily;} }
            await prefs?.setString('daily', jsonEncode(incomingDaily));
          } catch (_) {}
        }(),
        () async {
          try {
            // Keep stock snapshot and sales counters consistent, as in manual refresh.
            final responses = await Future.wait<Map<String, dynamic>>([
              api('/snapshot'),
              api('/sales'),
            ]);
            final incoming = list(responses[0]['products']).map((e) => map(e)).toList();
            final sold = map(responses[1]['sales']);
            if (incoming.isEmpty || !mounted) return;
            final nextBase = <String, dynamic>{
              for (final p in incoming) '${p['id']}': number(p['stock']),
            };
            if (jsonEncode(products) != jsonEncode(incoming) || jsonEncode(base) != jsonEncode(nextBase) || jsonEncode(previousSales) != jsonEncode(sold)) {
              void apply() {products = incoming; base = nextBase; previousSales = sold;}
              if (page == 2 || page == 3 || page == 7 || page == 8) {setState(apply);} else {apply();}
            }
            await prefs?.setString('products', jsonEncode(incoming));
            await prefs?.setString('base', jsonEncode(nextBase));
            await prefs?.setString('previousSales', jsonEncode(sold));
            await prefs?.setString('stockBaselineSales', jsonEncode(sold));
          } catch (_) { /* Preserve cached stock on connection errors. */ }
        }(),
      ]);
    } finally {
      if (DateTime.now().difference(lastHistoryAudit??DateTime(2000)).inHours>=24) auditKasaHistory();
      refreshingReadOnly = false;
    }
  }
 Future<void> refreshStock()async{setState(()=>busy=true);try{final s=await api('/snapshot');final sl=await api('/sales');final incoming=list(s['products']).map((e)=>map(e)).toList();if(incoming.isEmpty)throw StateError('PC 0 ürün gönderdi; mevcut stok korunuyor');final sold=map(sl['sales']);setState((){products=incoming;base={for(final p in incoming)'${p['id']}':number(p['stock'])};previousSales=sold;});await prefs!.setString('stockBaselineSales',jsonEncode(sold));await save();notice('${products.length} ürün ve başlangıç stokları güncellendi');}catch(e){notice('Stok alınamadı: $e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> refreshSales()async{setState(()=>busy=true);try{try{final central=await api('/daily-sales');setState(()=>daily=map(central['daily']));await prefs?.setString('daily',jsonEncode(daily));notice('PC günlük satış kayıtları güncellendi');return;}catch(_){ }final result=await api('/sales');final now=map(result['sales']);final today=day(DateTime.now());final bucket=map(daily[today]);for(final p in products){final id='${p['id']}';final current=number(now[id]);final old=number(previousSales[id]);final delta=max(0,current-old);if(delta>0)bucket[id]=number(bucket[id])+delta;previousSales[id]=current;}daily[today]=bucket;final oldest=day(DateTime.now().subtract(const Duration(days:6)));daily.removeWhere((date,_)=>date.compareTo(oldest)<0);await save();notice('Satışlar alındı • ${daily.length} günlük kayıt');}catch(e){notice('Satışlar alınamadı: $e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> refreshKasa()async{
  final requestedDay=day(selected);
  if(mounted)setState(()=>busy=true);
  try{
    final results=await Future.wait<Map<String,dynamic>>([
      api('/kasa?date=$requestedDay'),
      api('/daily-sales'),
    ]);
    if(!mounted||day(selected)!=requestedDay)return;
    if('${results[0]['date']}'!=requestedDay)throw StateError('Kasa yanıt tarihi farklı: ${results[0]['date']}');
    await rememberKasa(results[0]);
    final incomingDaily=map(results[1]['daily']);
    setState((){kasa=results[0];daily=incomingDaily;});
    await prefs?.setString('daily',jsonEncode(incomingDaily));
    notice('$requestedDay kasa ve satış kayıtları güncellendi');
  }catch(e){if(mounted&&day(selected)==requestedDay)notice('$requestedDay kayıtları alınamadı: $e');}
  finally{if(mounted)setState(()=>busy=false);}
}
 double remaining(Map<String,dynamic> p){final id='${p['id']}';return number(base[id]).toDouble()-max(0,number(previousSales[id])-number(map(jsonDecode(prefs?.getString('stockBaselineSales')??'{}'))[id])).toDouble();}
 bool fuel(Map<String,dynamic> p)=>fuelIds.split(',').map((e)=>e.trim()).contains('${p['id']}');
 String barcode(Map<String,dynamic> p){final b=list(p['barcodes']);return b.isEmpty?'':'${b.first}';}
 Map<String,dynamic>? findBarcode(String code){for(final p in products){if(list(p['barcodes']).any((e)=>'$e'==code))return p;}return null;}

 Future<void> barcodeErrorForm({Map<String,dynamic>? product,String? existingKey})async{
  final existing=map(barcodeErrors[existingKey]);
  final barcodeCtrl=TextEditingController(text:'${existing['barcode']??(product==null?'':barcode(product))}');
  final correctCtrl=TextEditingController(text:'${existing['correct_barcode']??''}');
  final noteCtrl=TextEditingController(text:'${existing['status']??''}');
  final productCtrl=TextEditingController(text:'${existing['product_name']??product?['name']??''}');
  final productId='${existing['product_id']??product?['id']??''}';
  final saved=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
   title:Text(existingKey==null?'Barkod Hatası Ekle':'Barkod Hatasını Düzenle'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:productCtrl,decoration:const InputDecoration(labelText:'Ürün adı')),
    TextField(controller:barcodeCtrl,decoration:const InputDecoration(labelText:'Hatalı barkod *')),
    TextField(controller:correctCtrl,decoration:const InputDecoration(labelText:'Doğru barkod (biliniyorsa)')),
    TextField(controller:noteCtrl,maxLines:2,decoration:const InputDecoration(labelText:'Hata açıklaması')),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('İptal')),
    FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Kaydet'))]));
  if(saved!=true)return;
  final code=barcodeCtrl.text.trim();if(code.isEmpty){notice('Hatalı barkodu girin');return;}
  final key=existingKey??'${DateTime.now().microsecondsSinceEpoch}';
  setState(()=>barcodeErrors[key]={...existing,'barcode':code,'product_id':productId,'product_name':productCtrl.text.trim(),
   'correct_barcode':correctCtrl.text.trim(),'status':noteCtrl.text.trim(),
   'date':existing['date']??DateTime.now().toIso8601String()});
  await save();notice('Barkod hatası kaydedildi');
 }
 Future<void> recordBarcodeError(String code)async{
  final key=code.trim();if(key.isEmpty)return;
  setState(()=>barcodeErrors['${DateTime.now().microsecondsSinceEpoch}']={'barcode':key,'date':DateTime.now().toIso8601String(),'status':'Bekliyor'});
  await save();notice('Barkod hatası kaydedildi: $key');
 }
 Future<void> editBarcodeError(String key)=>barcodeErrorForm(existingKey:key);
 List<List<dynamic>> barcodeErrorRows()=>[['Ürün kodu','Ürün adı','Hatalı barkod','Doğru barkod','Tarih','Açıklama'],
  ...barcodeErrors.entries.map((e){final v=map(e.value);return [v['product_id']??'',v['product_name']??'',v['barcode']??e.key,v['correct_barcode']??'',v['date']??'',v['status']??''];})];
 Widget barcodeErrorsPage()=>ListView(children:[
  SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>barcodeErrorForm(),icon:const Icon(Icons.add),label:const Text('Yeni Hata Ekle'))),
  const SizedBox(height:12),
  card('Barkod Hataları',Column(children:[
   for(final e in barcodeErrors.entries)ListTile(
    title:Text('${map(e.value)['product_name']??''} • ${map(e.value)['barcode']??e.key}',maxLines:2,overflow:TextOverflow.ellipsis),
    subtitle:Text('Doğru: ${map(e.value)['correct_barcode']??'-'} • ${map(e.value)['status']??''}'),
    onTap:()=>editBarcodeError(e.key),
    trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>confirmClear('Barkod hatasını sil?',()=>barcodeErrors.remove(e.key)))),
   if(barcodeErrors.isEmpty)const Text('Kayıt yok'),
   action('Barkod Hataları Excel',Icons.file_download,()=>exportCsv('SSOIL_BARKOD_HATALARI',barcodeErrorRows()))
  ]),icon:Icons.qr_code),
  action('Barkod hatalarını temizle',Icons.delete_sweep,()=>confirmClear('Tüm barkod hataları silinsin mi?',()=>barcodeErrors.clear()))
 ]);
 Future<void> scanCount()async{await Navigator.push(context,MaterialPageRoute(builder:(c)=>Scanner(onCode:(code){Navigator.pop(c);final p=findBarcode(code);if(p==null){recordBarcodeError(code);return;}addDiscrepancy('sayim',product:p);})));}
 Future<void> scan({bool order=false})async{await Navigator.push(context,MaterialPageRoute(builder:(c)=>Scanner(onCode:(code){Navigator.pop(c);final p=findBarcode(code);if(p==null){recordBarcodeError(code);return;}if(order){addOrder(p);}else{productDetail(p);}})));}
 void addOrder(Map<String,dynamic> p){
  final id='${p['id']}';String selected='${supplierOf[id]??''}';final qty=TextEditingController(text:'1');
  showDialog(context:context,builder:(dialog)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text('${p['name']} • Siparişe Ekle'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:suppliers.containsKey(selected)?selected:'',isExpanded:true,decoration:const InputDecoration(labelText:'Tedarikçi'),items:[const DropdownMenuItem(value:'',child:Text('Tedarikçi seç')),...suppliers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${map(e.value)['name']}')))],onChanged:(v)=>update(()=>selected=v??'')),TextButton.icon(onPressed:()async{Navigator.pop(dialog);addSupplier();notice('Tedarikçi ekledikten sonra Siparişe Ekle butonuna tekrar basın');},icon:const Icon(Icons.add),label:const Text('Yeni Tedarikçi Ekle')),TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Sipariş Adedi'))])),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('İptal')),FilledButton(onPressed:(){final amount=num.tryParse(qty.text.replaceAll(',','.'));if(amount==null||amount<=0){notice('Geçerli miktar gir');return;}setState((){orders[id]=number(orders[id])+amount;if(selected.isNotEmpty)supplierOf[id]=selected;orderUnits.putIfAbsent(id,()=> 'KOM');});save();Navigator.pop(dialog);notice('Sipariş listesine eklendi');},child:const Text('Siparişe Kaydet'))])));
 }
 Future<void> confirmClear(String title,VoidCallback onClear)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:const Text('Bu listedeki kayıtlar temizlensin mi? Bu işlem geri alınamaz.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Temizle'))]));if(ok==true){setState(onClear);await save();notice(pending.isEmpty?'Temizleme PC ile eşitlendi':'Temizleme telefonda kaydedildi; PC onayı bekleniyor (${pending.length})');}}
 Map<String,dynamic>? byId(String id){for(final p in products){if('${p['id']}'==id)return p;}return null;}
 Future<void> exportCsv(String filename,List<List<dynamic>> rows)async{
  final book=xl.Excel.createExcel(); final sheet=book['Rapor'];
  for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}
  book.setDefaultSheet('Rapor'); final bytes=book.encode();if(bytes==null){notice('Excel oluşturulamadı');return;}
  await deliverExcel('$filename.xlsx',bytes);
 }
 Future<void> deliverExcel(String filename,List<int> bytes)async{
  final option=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.save_alt),title:const Text('Telefona Kaydet'),onTap:()=>Navigator.pop(c,'save')),ListTile(leading:const Icon(Icons.share),title:const Text('Paylaş'),onTap:()=>Navigator.pop(c,'share'))])));
  if(option=='save'){
   try{final path=await FilePicker.platform.saveFile(dialogTitle:'Excel dosyasını kaydet',fileName:filename,type:FileType.custom,allowedExtensions:['xlsx'],bytes:Uint8List.fromList(bytes));if(path!=null)notice('Excel kaydedildi');}
   catch(e){notice('Kaydetme başarısız: $e');}
  }else if(option=='share'){
   final dir=await getTemporaryDirectory();final f=File('${dir.path}/$filename');await f.writeAsBytes(bytes);await Share.shareXFiles([XFile(f.path)],text:filename);
  }
 }
 Future<void> exportProducts()async{await exportCsv('SSOIL_TUM_URUNLER',[['Ürün kodu','Ürün adı','Barkod','Stok','Fiyat KM'],...products.map((p)=>[p['id'],p['name'],barcode(p),remaining(p),p['price']])]);}
 Future<void> exportOrders([String? onlySupplier])async{
  if(orders.isEmpty){notice('Sipariş listesi boş');return;}
  final book=xl.Excel.createExcel();
  final grouped=<String,List<String>>{};
  for(final id in orders.keys){final sid='${supplierOf[id]??''}';if(onlySupplier!=null&&sid!=onlySupplier)continue;grouped.putIfAbsent(sid,()=>[]).add(id);}
  for(final entry in grouped.entries){
   final name='${map(suppliers[entry.key])['name']??'TEDARIKCISIZ'}';
   final sheet=book[name.replaceAll(RegExp(r'[\\/*?:\[\]]'),'_').substring(0,min(31,name.length))];
   final rows=<List<dynamic>>[['Barkod','Ürün adı','Miktar','Birim (KOM/PAK)','Ürün kodu'],for(final id in entry.value)[barcode(byId(id)??{}),byId(id)?['name']??id,orders[id],orderUnits[id]??'KOM',id]];
   for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}
  }
  book.delete('Sheet1');final bytes=book.encode();if(bytes!=null)await deliverExcel('SSOIL_SIPARISLER.xlsx',bytes);
 }
 Future<void> exportAll()async{
  final book=xl.Excel.createExcel();
  void add(String name,List<List<dynamic>> rows){final sheet=book[name];for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}}
  add('Stok',[['Kod','Ürün','Barkod','Stok','Fiyat'],...products.map((p)=>[p['id'],p['name'],barcode(p),remaining(p),p['price']])]);
  add('Siparişler',[['Kod','Ürün','Tedarikçi','Miktar','Birim'],...orders.entries.map((e)=>[e.key,byId(e.key)?['name']??'',map(suppliers['${supplierOf[e.key]??''}'])['name']??'',e.value,orderUnits[e.key]??'KOM'])]);
  add('Eksik Fazla',[['Kod','Sistem','Sayılan','Fark'],...discrepancies.values.map((v){final d=map(v);return [d['product_id'],d['system_stock'],d['counted_stock'],d['difference']];})]);
  add('Etiketler',[['Kod','Ürün','Barkod','Fiyat'],...labels.values.map((v){final p=map(v);return [p['id'],p['name'],barcode(p),p['price']];})]);
  add('Barkod Hataları',barcodeErrorRows());
  add('Tedarikçiler',[['Firma','Telefon'],...suppliers.values.map((v)=>[map(v)['name'],map(v)['phone']])]);
  book.delete('Sheet1');final bytes=book.encode();if(bytes!=null)await deliverExcel('SSOIL_TUM_RAPORLAR.xlsx',bytes);
 }
 Future<void> exportDiscrepancies()async{await exportCsv('SSOIL_EKSIK_FAZLA',[['Ürün kodu','Ürün adı','Barkod','Sistem stoku','Sayılan stok','Fark','Açıklama','Tarih'],...discrepancies.values.map((v){final d=map(v),p=byId('${d['product_id']}')??{};return [d['product_id'],p['name']??'',barcode(p),d['system_stock']??'',d['counted_stock']??'',d['difference']??0,d['note']??'',d['date']??''];})]);}
 Future<void> addDiscrepancy(String kind,{Map<String,dynamic>? product})async{
  final code=TextEditingController(text:product==null?'':'${product['id']}'),qty=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Stok Sayımı'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:code,decoration:const InputDecoration(labelText:'Ürün kodu veya barkod')),const SizedBox(height:8),TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Sayılan toplam stok')),const SizedBox(height:8),TextField(controller:note,decoration:const InputDecoration(labelText:'Açıklama'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kaydet'))]));
  if(ok!=true)return;final p=product??findBarcode(code.text)??byId(code.text.trim());final counted=num.tryParse(qty.text.replaceAll(',','.'));
  if(p==null||counted==null||counted<0){notice('Geçerli ürün ve sayılan stok gir');return;}
  final system=remaining(p);final difference=counted-system;
  final id='${p['id']}';final data={'product_id':id,'system_stock':system,'counted_stock':counted,'difference':difference,'note':note.text,'date':DateTime.now().toIso8601String()};
  setState(()=>discrepancies[id]=data);await save();notice('Stok farkı: ${difference>0?'+':''}$difference');
 }
 Widget countPage()=>ListView(children:[card('Stok Sayım / Eksik - Fazla',Column(children:[Wrap(spacing:8,runSpacing:8,children:[action('Barkod Oku',Icons.qr_code_scanner,scanCount),action('Sayım Gir',Icons.fact_check,()=>addDiscrepancy('sayim')),action('Tüm Ürünler Excel',Icons.file_download,exportProducts),action('Eksik/Fazla Excel',Icons.table_view,exportDiscrepancies)]),const SizedBox(height:8),for(final e in discrepancies.entries)ListTile(title:Text("${byId('${map(e.value)['product_id']}')?['name']??map(e.value)['product_id']}"),subtitle:Text('Sistem: ${map(e.value)['system_stock']} • Sayılan: ${map(e.value)['counted_stock']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${number(map(e.value)['difference'])>0?'+':''}${map(e.value)['difference']}',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold)),IconButton(icon:const Icon(Icons.close),onPressed:()=>confirmClear('Bu kaydı sil?',(){discrepancies.remove(e.key);}))])),OutlinedButton.icon(onPressed:()=>confirmClear('Eksik/Fazla listesini temizle?',()=>discrepancies.clear()),icon:const Icon(Icons.delete_sweep),label:const Text('Listeyi temizle'))]),icon:Icons.fact_check)]);

 Future<void> addPhoto(Map<String,dynamic> p,ImageSource src)async{final img=await ImagePicker().pickImage(source:src,imageQuality:70,maxWidth:1000);if(img==null)return;final dir=await getApplicationDocumentsDirectory();final f=await File(img.path).copy('${dir.path}/ssoil_${p['id']}.jpg');setState(()=>photos['${p['id']}']=f.path);await save();}
 void productDetail(Map<String, dynamic> p) {
   final id = '${p['id']}';
   showDialog<void>(
     context: context,
     barrierDismissible: true,
     builder: (dialogContext) => LayoutBuilder(
       builder: (dialogContext, constraints) {
         final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
         return Dialog(
           backgroundColor: Theme.of(dialogContext).cardColor,
           insetPadding: EdgeInsets.fromLTRB(12, 12, 12, 12 + keyboardHeight),
           child: SizedBox(
             width: double.infinity,
             height: constraints.maxHeight - 24 - keyboardHeight,
             child: StatefulBuilder(
               builder: (innerContext, update) => Column(
                 children: [
                   Padding(
                     padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                     child: Row(children: [
                       Expanded(child: Text('${p['name']}', maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                       IconButton(icon: const Icon(Icons.close),
                         tooltip: 'Kapat',
                         onPressed: () => Navigator.pop(innerContext)),
                     ]),
                   ),
                   Expanded(
                     child: SingleChildScrollView(
                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                       padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           photo(id, 100),
                           const SizedBox(height: 8),
                           Text('Šifra: $id  •  Barkod: ${barcode(p)}'),
                           Text('Cijena: ${money(p['price'])} KM'),
                           Text('Tahmini kalan stok: ${money(remaining(p))}'),
                           const SizedBox(height: 8),
                           const SizedBox(height:12),
                           Row(children:[Expanded(child:action('Siparişe Ekle',Icons.add_shopping_cart,()=>addOrder(p))),const SizedBox(width:8),Expanded(child:action('Tedarikçi Seç',Icons.store,(){Navigator.pop(innerContext);assignSupplier(p);}))]),
                           const SizedBox(height:8),
                           Row(children:[Expanded(child:action('Eksik',Icons.trending_down,(){Navigator.pop(innerContext);addDiscrepancy('eksik',product:p);})),const SizedBox(width:8),Expanded(child:action('Fazla',Icons.trending_up,(){Navigator.pop(innerContext);addDiscrepancy('fazla',product:p);}))]),
                           const SizedBox(height:8),
                           Row(children:[Expanded(child:action('Etiket Yok',Icons.label_off,(){setState(()=>labels[id]=p);save();notice('Etiket listesine eklendi');})),const SizedBox(width:8),Expanded(child:action('Barkod Hatalı',Icons.report_problem_outlined,(){Navigator.pop(innerContext);barcodeErrorForm(product:p);}))]),
                           SizedBox(width:double.infinity,child:action('Fotoğraf Ekle / Düzenle',Icons.add_photo_alternate,(){showModalBottomSheet(context:innerContext,builder:(sheet)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.camera_alt),title:const Text('Kamera'),onTap:()async{Navigator.pop(sheet);await addPhoto(p,ImageSource.camera);update((){});}),ListTile(leading:const Icon(Icons.image),title:const Text('Galeri'),onTap:()async{Navigator.pop(sheet);await addPhoto(p,ImageSource.gallery);update((){});}),ListTile(leading:const Icon(Icons.delete),title:const Text('Fotoğrafı Sil'),onTap:(){Navigator.pop(sheet);setState(()=>photos.remove(id));save();update((){});})]))); })),
                           SizedBox(width:double.infinity,child:action('Kritik Stok Seviyesi: ${minimum[id]??'10'}',Icons.tune,(){Navigator.pop(innerContext);setMinimum(p);})),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ),
         );
       },
     ),
   );
 }
 void setMinimum(Map<String,dynamic> p){final t=TextEditingController(text:'${minimum['${p['id']}']??''}');showDialog(context:context,builder:(c)=>AlertDialog(title:Text('${p['name']} • Minimum stok'),content:TextField(controller:t,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Kritik seviye')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('İptal')),FilledButton(onPressed:(){setState(()=>minimum['${p['id']}']=number(t.text));save();Navigator.pop(c);},child:const Text('Kaydet'))]));}
 void assignSupplier(Map<String,dynamic> p){showDialog(context:context,builder:(c)=>AlertDialog(title:Text('${p['name']} • Tedarikçi'),content:SizedBox(width:300,child:Column(mainAxisSize:MainAxisSize.min,children:[for(final e in suppliers.entries)ListTile(title:Text('${map(e.value)['name']}'),onTap:(){setState(()=>supplierOf['${p['id']}']=e.key);save();Navigator.pop(c);}),ListTile(title:const Text('Yeni tedarikçi ekle'),leading:const Icon(Icons.add),onTap:(){Navigator.pop(c);addSupplier();})])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Kapat'))]));}
 void editSupplier(String id){
  final old=map(suppliers[id]);final name=TextEditingController(text:'${old['name']??''}'),phone=TextEditingController(text:'${old['phone']??''}');
  showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('Tedarikçiyi Düzenle'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Firma adı')),TextField(controller:phone,decoration:const InputDecoration(labelText:'Telefon'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('İptal')),FilledButton(onPressed:(){if(name.text.trim().isEmpty)return;setState(()=>suppliers[id]={'name':name.text.trim(),'phone':phone.text.trim()});save();Navigator.pop(c);},child:const Text('Kaydet'))]));
 }
 void deleteSupplier(String id){confirmClear('Tedarikçi silinsin mi? Ürün eşleşmeleri de kaldırılacak.',(){suppliers.remove(id);supplierOf.removeWhere((key,value)=>'$value'==id);});}
 void addSupplier(){final name=TextEditingController(),phone=TextEditingController();showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('Tedarikçi ekle'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Firma adı')),const SizedBox(height:8),TextField(controller:phone,decoration:const InputDecoration(labelText:'Telefon'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('İptal')),FilledButton(onPressed:(){if(name.text.trim().isEmpty)return;final id=DateTime.now().microsecondsSinceEpoch.toString();setState(()=>suppliers[id]={'name':name.text.trim(),'phone':phone.text.trim()});save();Navigator.pop(c);},child:const Text('Kaydet'))]));}
 Widget photo(String id,double size){final path='${photos[id]??''}';return Container(width:size,height:size,decoration:BoxDecoration(color:const Color(0xff253143),borderRadius:BorderRadius.circular(14)),clipBehavior:Clip.antiAlias,child:path.isNotEmpty&&File(path).existsSync()?Image.file(File(path),fit:BoxFit.cover):Icon(Icons.inventory_2_outlined,color:Theme.of(context).colorScheme.primary));}
  Widget field(String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: ValueKey<String>('settings-$label'),
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );
 Widget action(String label,IconData icon,VoidCallback f)=>OutlinedButton.icon(onPressed:f,icon:Icon(icon,size:18),label:Text(label));
 Widget card(String title,Widget child,{IconData icon=Icons.dashboard})=>Card(margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(width:8),Expanded(child:Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)))]),const SizedBox(height:12),child])));
 Widget metric(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(a)),Text(b,style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))]));
 Widget homePage()=>ListView(children:[card('Hızlı işlemler',LayoutBuilder(builder:(context,constraints){
  final width=(constraints.maxWidth-10)/2;
  Widget shortcut(String title,IconData icon,VoidCallback callback)=>SizedBox(width:width,height:65,child:OutlinedButton.icon(onPressed:callback,icon:Icon(icon,size:22),label:Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:6))));
  return Wrap(spacing:10,runSpacing:10,children:[
   shortcut('Barkod Oku',Icons.qr_code_scanner,()=>scan()),shortcut('Kasa',Icons.point_of_sale,()=>setState(()=>page=1)),
   shortcut('Stok',Icons.inventory_2,()=>setState(()=>page=2)),shortcut('Siparişler',Icons.shopping_cart,()=>setState(()=>page=3)),
   shortcut('Stok Sayım',Icons.fact_check,()=>setState(()=>page=7)),shortcut('Tedarikçiler',Icons.business,()=>setState(()=>page=3)),
   shortcut('Barkod Hataları',Icons.report_problem_outlined,()=>setState(()=>page=8)),shortcut('Raporlar',Icons.analytics,()=>setState(()=>page=5)),
    shortcut('Vardiya',Icons.account_balance_wallet,()=>setState(()=>page=9)),
   shortcut('PC Güncelle',Icons.computer,syncAllManually),shortcut('Supabase Güncelle',Icons.cloud_sync,syncCloudManually)
  ]);
 }),icon:Icons.bolt)]);
 double salesTotal(bool isFuel){final counts=map(daily[day(selected)]);double total=0;for(final p in products){if(fuel(p)==isFuel)total+=number(counts['${p['id']}']).toDouble()*number(p['price']).toDouble();}return total;}
 // Independent persistent Kasa archive; never changes the original PC/Supabase sync path.
 Future<void> rememberKasa(Map<String,dynamic> response)async{
  final date='${response['date']??''}';
  if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date))return;
  // Missing fields do not erase previously verified non-null values.
  final merged=map(kasaArchive[date]);
  for(final e in response.entries){if(e.value!=null)merged[e.key]=e.value;}
  kasaArchive[date]=merged;
  await prefs?.setString('ssoilKasaArchiveV1',jsonEncode(kasaArchive));
 }
 Future<void> auditKasaHistory()async{
  if(historyAuditBusy||prefs==null)return;
  historyAuditBusy=true;
  try{
   // Check all previously archived days, including zeros and complete records.
   // Bound each pass to avoid interrupting the three-second live updates.
   final dates=kasaArchive.keys.where((d)=>RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)).toList()..sort();
   for(final date in dates){
    if(!mounted)break;
    try{final r=await api('/kasa?date=$date');if('${r['date']}'==date){await rememberKasa(r);if(day(selected)==date&&mounted)setState(()=>kasa=map(kasaArchive[date]));}}catch(_){/* Offline history remains available. */}
   }
   lastHistoryAudit=DateTime.now();
   await prefs?.setString('ssoilLastKasaAudit',lastHistoryAudit!.toIso8601String());
  }finally{historyAuditBusy=false;}
 }
 static const fuelNames={'1':'Benzin','2':'Dizel','3':'Dizel+'};
 static const fuelKeys={'1':'benzin','2':'dizel','3':'dizel_plus'};
 Future<void> fetchFuelPrices()async{
  final date=day(selected);
  final r=await cloudRequest('GET','ssoil_fuel_daily_prices?select=fuel_type,purchase_price,sale_price,sale_date&sale_date=eq.$date');
  if(r==null||r.statusCode!=200)return;
  try{
   final rows=list(jsonDecode(r.body));
   final byType=<String,dynamic>{};for(final row in rows){final item=map(row);byType['${item['fuel_type']}']=item;}
   if(byType.isNotEmpty){fuelPrices[date]=byType;await prefs?.setString('ssoilFuelPricesV1',jsonEncode(fuelPrices));if(mounted&&day(selected)==date)setState((){});}
  }catch(_){ }
 }
 Future<void> fetchHistoricalFuelStock()async{
  final date=day(selected);
  if(date==day(DateTime.now()))return;
  final response=await cloudRequest('GET','ssoil_fuel_daily_stock?select=fuel_id,closing_liters&stock_date=eq.$date');
  if(response?.statusCode!=200)return;
  try{
   final values=<String,dynamic>{};
   for(final row in list(jsonDecode(response!.body))){
    final item=map(row);
    if(item['closing_liters']!=null)values['${item['fuel_id']}']=item['closing_liters'];
   }
   historicalFuelStock[date]=values;
   if(mounted&&day(selected)==date)setState((){});
  }catch(_){}
 }
 Future<void> editPurchasePrices()async{
  final current=map(fuelPrices[day(DateTime.now())]);
  final controllers={for(final key in fuelKeys.values)key:TextEditingController(text:'${map(current[key])['purchase_price']??''}')};
  final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Yakıt alış fiyatları (KM/L)'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[for(final e in fuelKeys.entries)TextField(controller:controllers[e.value],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'${fuelNames[e.key]} alış fiyatı'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kaydet'))]));
  if(confirmed!=true){Future<void>.delayed(const Duration(milliseconds:400),(){for(final c in controllers.values)c.dispose();});return;}
  final entries=<Map<String,dynamic>>[];
  for(final e in controllers.entries){final n=num.tryParse(e.value.text.trim().replaceAll(',','.'));if(n==null||n<0){notice('Geçersiz alış fiyatı: ${e.key}');Future<void>.delayed(const Duration(milliseconds:400),(){for(final c in controllers.values)c.dispose();});return;}entries.add({'fuel_type':e.key,'purchase_price':n});}
  Future<void>.delayed(const Duration(milliseconds:400),(){for(final c in controllers.values)c.dispose();});
  // Write only the existing purchase-price table. Never modify SQL Server.
  final response=await cloudRequest('POST','ssoil_fuel_purchase_prices?on_conflict=fuel_type',body:entries,prefer:'resolution=merge-duplicates,return=representation');
  if(response==null||!(response.statusCode==200||response.statusCode==201||response.statusCode==204)){notice('Supabase kaydı başarısız: $cloudError');return;}
  final date=day(DateTime.now());final values=map(fuelPrices[date]);
  for(final row in entries){final key='${row['fuel_type']}';values[key]={...map(values[key]),'purchase_price':row['purchase_price']};}
  fuelPrices[date]=values;await prefs?.setString('ssoilFuelPricesV1',jsonEncode(fuelPrices));
  if(mounted)setState((){});notice('Alış fiyatları Supabase üzerinde kaydedildi');
 }
 Widget kasaLine(String label,String value,{bool strong=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:13),child:Row(children:[Expanded(child:Text(label,style:TextStyle(fontSize:15,fontWeight:strong?FontWeight.w700:FontWeight.normal))),Text(value,style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:const Color(0xffb32130)))]));
 String kasaAmount(String key)=>kasa[key]==null?'Veri yok':'${money(kasa[key])} KM';
 Widget kasaBox(String title,IconData icon,List<Widget> children)=>Card(color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),side:const BorderSide(color:Color(0xffeeeeee))),margin:const EdgeInsets.symmetric(vertical:8),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:const Color(0xffb32130)),const SizedBox(width:10),Text(title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold))]),const SizedBox(height:15),...children])));
 Widget fuelStockRow(String id){
  final p=products.where((x)=>'${x['id']}'==id).firstOrNull;
  final historical=day(selected)!=day(DateTime.now());
   final stored=map(historicalFuelStock[day(selected)])[id];
   final double? value=historical?(stored==null?null:number(stored).toDouble()):(p==null?null:remaining(p));
  final color=id=='1'?const Color(0xff1db661):id=='2'?const Color(0xffffd665):const Color(0xffd80020);
  return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Container(width:90,padding:const EdgeInsets.symmetric(vertical:11),decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(8)),child:Text(fuelNames[id]!,textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,color:id=='2'?Colors.black:Colors.white))),const SizedBox(width:12),Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:value==null?0:(value/8000).clamp(0.0,1.0),minHeight:17,backgroundColor:const Color(0xffeeeeee),valueColor:AlwaysStoppedAnimation<Color>(color)))),const SizedBox(width:12),SizedBox(width:85,child:Text(value==null?'Veri yok':'${value.toStringAsFixed(0)} L',textAlign:TextAlign.end,style:const TextStyle(fontWeight:FontWeight.bold)))]));
 }
 Widget kasaPage()=>ListView(children:[
  Row(children:[Expanded(child:Text('Tarih: ${day(selected)}',style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:()async{final d=await showDatePicker(context:context,initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null){setState((){selected=d;followToday=day(d)==day(DateTime.now());kasa=map(kasaArchive[day(d)]);});await refreshKasa();await fetchFuelPrices();await fetchHistoricalFuelStock();}},icon:const Icon(Icons.calendar_month)),FilledButton.icon(onPressed:()async{await refreshKasa();await fetchFuelPrices();await fetchHistoricalFuelStock();},icon:const Icon(Icons.refresh),label:const Text('Güncelle'))]),
  kasaBox('Günlük Satış',Icons.payments,[
   kasaLine('Nakit Yakıt Market',kasa['cash_market']==null||kasa['cash_fuel']==null?'Veri yok':'${money(number(kasa['cash_market'])+number(kasa['cash_fuel']))} KM'),
   kasaLine('Nakit Dopuna (MTEL + AERO)',kasa['mtel_dopuna']==null||kasa['aero_dopuna']==null?'Veri yok':'${money(number(kasa['mtel_dopuna'])+number(kasa['aero_dopuna']))} KM'),
   kasaLine('Nakit (Dopuna dahil)',kasaAmount('cash')),
   kasaLine('Kredi Kartı',kasaAmount('card')),
   const Divider(),kasaLine('Genel Toplam',kasa['cash']==null||kasa['card']==null?'Veri yok':'${money(number(kasa['cash'])+number(kasa['card']))} KM',strong:true),
  ]),
  kasaBox('Satış Grupları',Icons.storefront,[
   kasaLine('Yakıt',kasaAmount('fuel_sales')),kasaLine('Market',kasaAmount('market_sales')),
   kasaLine('MTEL Dopuna',kasaAmount('mtel_dopuna')),kasaLine('AERO Dopuna',kasaAmount('aero_dopuna')),
  ]),
  kasaBox('Yakıt Stokları',Icons.local_gas_station,[fuelStockRow('2'),fuelStockRow('3'),fuelStockRow('1')]),
  kasaBox('Güncel Yakıt Fiyatları',Icons.trending_up,[
   const Row(children:[Expanded(child:Text('Yakıt',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text('Alış Fiyatı\n(KM/L)',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text('Satış Fiyatı\n(KM/L)',textAlign:TextAlign.end,style:TextStyle(fontWeight:FontWeight.bold)))]),
   for(final id in ['2','3','1']) Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Row(children:[Expanded(child:Text(fuelNames[id]!,style:const TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text(map(map(fuelPrices[day(selected)])[fuelKeys[id]])['purchase_price']==null?'Veri yok':money(map(map(fuelPrices[day(selected)])[fuelKeys[id]])['purchase_price']),textAlign:TextAlign.center)),Expanded(child:Text(map(map(fuelPrices[day(selected)])[fuelKeys[id]])['sale_price']==null?'Veri yok':money(map(map(fuelPrices[day(selected)])[fuelKeys[id]])['sale_price']),textAlign:TextAlign.end,style:const TextStyle(color:Color(0xffb32130),fontWeight:FontWeight.bold)))])),
  ]),
 ]);
 Widget stockPage(){final q=search.text.toLowerCase();final filtered=products.where((p)=>'${p['name']} ${p['id']} ${barcode(p)}'.toLowerCase().contains(q)&&(stockSupplier=='all'||(stockSupplier=='none'?'${supplierOf['${p['id']}']??''}'.isEmpty:'${supplierOf['${p['id']}']??''}'==stockSupplier))).toList();return Column(children:[Row(children:[Expanded(child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Ürün, şifra veya barkod'))),IconButton(onPressed:()=>scan(),icon:const Icon(Icons.qr_code_scanner))]),const SizedBox(height:8),DropdownButtonFormField<String>(value:stockSupplier,isExpanded:true,decoration:const InputDecoration(labelText:'Tedarikçiye göre filtrele'),items:[const DropdownMenuItem(value:'all',child:Text('Tüm tedarikçiler')),const DropdownMenuItem(value:'none',child:Text('Tedarikçisi olmayanlar')),...suppliers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${map(e.value)['name']}')))],onChanged:(v)=>setState(()=>stockSupplier=v??'all')),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton.icon(onPressed:refreshStock,icon:const Icon(Icons.sync),label:const Text('Stok Güncelle')))]),Expanded(child:ListView.builder(itemCount:filtered.length,itemBuilder:(c,i){final p=filtered[i];return Card(child:ListTile(onTap:()=>productDetail(p),leading:photo('${p['id']}',48),title:Text('${p['name']}',maxLines:2),subtitle:Text('Šifra: ${p['id']} • Cijena: ${money(p['price'])} KM'),trailing:Text('${money(remaining(p))}\nKalan',textAlign:TextAlign.end)));}))]);}
 String stockSupplier='all';
 final search=TextEditingController();
 void supplierOrdersPage(String supplierId){
   final supplierName=supplierId.isEmpty?'Tedarikçisi tanımlanmayanlar':'${map(suppliers[supplierId])['name']??'Tedarikçi'}';
   showDialog<void>(context:context,builder:(routeContext)=>Dialog(backgroundColor:Theme.of(context).cardColor,insetPadding:const EdgeInsets.symmetric(horizontal:12,vertical:30),child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.of(routeContext).size.height*0.85),child:StatefulBuilder(builder:(routeContext,update){
     final ids=orders.keys.where((id)=>'${supplierOf[id]??''}'==supplierId).toList();
     return ListView(shrinkWrap:true,padding:const EdgeInsets.all(12),children:[Text(supplierName,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),
       for(final id in ids)Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('${products.where((p)=>'${p['id']}'==id).firstOrNull?['name']??id}',style:const TextStyle(fontWeight:FontWeight.bold)),
         const SizedBox(height:6),Text('Šifra: $id • Barkod: ${products.where((p)=>'${p['id']}'==id).firstOrNull==null?'':barcode(products.firstWhere((p)=>'${p['id']}'==id))}'),
         Row(children:[PopupMenuButton<String>(tooltip:'KOM / PAK',onSelected:(v){setState(()=>orderUnits[id]=v);update((){});save();},itemBuilder:(c)=>[const PopupMenuItem(value:'KOM',child:Text('KOM')),const PopupMenuItem(value:'PAK',child:Text('PAK'))],child:Padding(padding:const EdgeInsets.all(8),child:Text('${orderUnits[id]??'KOM'} ▾'))),
           const Spacer(),IconButton(tooltip:'Azalt',onPressed:(){setState((){final q=number(orders[id]);if(q>1){orders[id]=q-1;}else{orders.remove(id);orderUnits.remove(id);}});update((){});save();},icon:const Icon(Icons.remove_circle_outline)),Text('${orders[id]??0}'),IconButton(tooltip:'Artır',onPressed:(){setState(()=>orders[id]=number(orders[id])+1);update((){});save();},icon:const Icon(Icons.add_circle_outline)),IconButton(tooltip:'Sil',onPressed:(){setState((){orders.remove(id);orderUnits.remove(id);});update((){});save();},icon:const Icon(Icons.delete_outline))])
       ]))),
       if(ids.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Bu tedarikçi için sipariş bulunmuyor.')),
       action('Bu tedarikçinin Exceli',Icons.file_download,()=>exportOrders(supplierId)),
       action('Bu tedarikçinin siparişlerini temizle',Icons.delete_sweep,()async{
         await confirmClear('Bu tedarikçinin siparişleri PC merkezinden de silinsin mi?',(){
           for(final id in List<String>.from(ids)){orders.remove(id);orderUnits.remove(id);}
         });
         update((){});
       }),
     ]);
   }))));
 }
 Widget ordersPage(){
   final grouped=<String,int>{};for(final id in orders.keys){final sid='${supplierOf[id]??''}';grouped[sid]=(grouped[sid]??0)+1;}
   return ListView(children:[
     Wrap(spacing:8,runSpacing:8,children:[action('Tedarikçi ekle',Icons.add_business,addSupplier),action('Barkodla ekle',Icons.qr_code_scanner,()=>scan(order:true)),action('Kritik stoktan ekle',Icons.warning_amber,(){int n=0;for(final p in products){final id='${p['id']}';if(minimum.containsKey(id)&&remaining(p)<=number(minimum[id])){orders[id]=max(1,number(minimum[id])-remaining(p));n++;}}setState((){});save();notice('$n ürün eklendi');})]),
     const SizedBox(height:10),card('Tedarikçiler',Column(children:[
       for(final e in suppliers.entries)ListTile(leading:const Icon(Icons.business),title:Text('${map(e.value)['name']}'),subtitle:Text('${grouped[e.key]??0} sipariş kalemi'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')editSupplier(e.key);else if(v=='delete')deleteSupplier(e.key);else supplierOrdersPage(e.key);},itemBuilder:(c)=>[const PopupMenuItem(value:'open',child:Text('Siparişler')),const PopupMenuItem(value:'edit',child:Text('Düzenle')),const PopupMenuItem(value:'delete',child:Text('Sil'))]),onTap:()=>supplierOrdersPage(e.key)),
       if(grouped.containsKey(''))ListTile(title:const Text('Tedarikçisi tanımlanmayanlar'),subtitle:Text('${grouped['']} sipariş kalemi'),trailing:const Icon(Icons.chevron_right),onTap:()=>supplierOrdersPage('')),
     ]),icon:Icons.business),
     Wrap(spacing:8,runSpacing:8,children:[action('Tedarikçiye göre Excel',Icons.file_download,()=>exportOrders()),action('Siparişleri temizle',Icons.delete_sweep,()=>confirmClear('Siparişleri temizle?',(){orders.clear();orderUnits.clear();}))]),
     card('Kritik stok ayarı',const Text('Ürün detayında minimum stok seviyesini belirleyebilir, ardından kritik stokları siparişe ekleyebilirsiniz.'),icon:Icons.warning_amber)
   ]);
 }
 Widget topPage(){final totals=<String,num>{};for(final d in daily.values){for(final e in map(d).entries){totals[e.key]=(totals[e.key]??0)+number(e.value);}}final sorted=products.where((p)=>!fuel(p)&&totals.containsKey('${p['id']}')).toList()..sort((a,b)=>number(totals['${b['id']}']).compareTo(number(totals['${a['id']}'])));return Column(children:[Row(children:[Expanded(child:Text('Son ${daily.length} gün • Akaryakıt hariç ilk 100')),FilledButton.icon(onPressed:refreshSales,icon:const Icon(Icons.refresh),label:const Text('Güncelle'))]),Expanded(child:ListView.builder(itemCount:min(100,sorted.length),itemBuilder:(c,i){final p=sorted[i];return Card(child:ListTile(leading:photo('${p['id']}',48),title:Text('${i+1}. ${p['name']}'),subtitle:Text('Šifra: ${p['id']}'),trailing:Text('${money(totals['${p['id']}'])} adet')));} ))]);}
 String labelMode='custom';
 double labelWidthMm=38,labelHeightMm=25,labelGapMm=0,labelMarginMm=0;

 Future<void> editLabelDimensions()async{
  final w=TextEditingController(text:'$labelWidthMm'),h=TextEditingController(text:'$labelHeightMm'),m=TextEditingController(text:'$labelMarginMm'),g=TextEditingController(text:'$labelGapMm');
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Etiket ölçüleri (mm)'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:w,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Genişlik (mm)')),TextField(controller:h,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Yükseklik (mm)')),TextField(controller:m,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'İç boşluk (mm)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Uygula'))]));
  if(ok!=true)return;final nw=double.tryParse(w.text.replaceAll(',','.')),nh=double.tryParse(h.text.replaceAll(',','.')),nm=double.tryParse(m.text.replaceAll(',','.')),ng=double.tryParse(g.text.replaceAll(',','.'));
  if(nw==null||nh==null||nm==null||ng==null||nw<20||nh<15||nw>210||nh>297||nm<0||nm>5||ng<0||ng>15){notice('Geçerli ölçüler gir (mm)');return;}
  setState((){labelWidthMm=nw;labelHeightMm=nh;labelMarginMm=nm;labelGapMm=ng;});
 }
 Future<void> printLabels()async{
  if(labels.isEmpty){notice('Etiket listesi boş');return;}
  final unit=PdfPageFormat.mm;
  final width=labelWidthMm*unit,height=labelHeightMm*unit,gap=labelGapMm*unit;
  pw.Widget labelWidget(Map<String,dynamic> item){
   final fontSize=max(5.0,min(10.0,labelHeightMm/3.2));
   final code=barcode(item);
   return pw.Container(padding:pw.EdgeInsets.all(labelMarginMm*unit),child:pw.Column(mainAxisAlignment:pw.MainAxisAlignment.center,crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
    pw.Text('${item['name']}',maxLines:2,style:pw.TextStyle(fontSize:fontSize,fontWeight:pw.FontWeight.bold)),
    pw.Text('Sifra: ${item['id']}    ${money(item['price'])} KM',style:pw.TextStyle(fontSize:max(5.0,fontSize-1))),
    if(code.isNotEmpty)...[pw.SizedBox(height:max(7.0,min(22.0,height*0.26)),child:pw.BarcodeWidget(barcode:pw.Barcode.code128(),data:code,drawText:false)),pw.Center(child:pw.Text(code,style:pw.TextStyle(fontSize:max(6.0,fontSize-1))))]
   ]));
  }
  final pdf=pw.Document();final items=labels.values.map((e)=>map(e)).toList();
  if(labelMode=='custom'){
   for(final item in items){pdf.addPage(pw.Page(pageFormat:PdfPageFormat(width,height),margin:pw.EdgeInsets.zero,build:(c)=>labelWidget(item)));}
  }else{
   final pageFormat=labelMode=='a4'?PdfPageFormat.a4:PdfPageFormat(3*width+2*gap,3*height+2*gap);
   final margin=labelMode=='a4'?10*unit:0.0;
   final usableW=pageFormat.width-2*margin,usableH=pageFormat.height-2*margin;
   final cols=max(1,((usableW+gap)/(width+gap)).floor());
   final rows=max(1,((usableH+gap)/(height+gap)).floor());
   final count=cols*rows;
   if(width>usableW||height>usableH){notice('Etiket ölçüsü seçilen kağıda sığmıyor');return;}
   for(var start=0;start<items.length;start+=count){
    final chunk=items.skip(start).take(count).toList();
    pdf.addPage(pw.Page(pageFormat:pageFormat,margin:pw.EdgeInsets.all(margin),build:(c)=>pw.Wrap(spacing:gap,runSpacing:gap,children:[for(final item in chunk)pw.SizedBox(width:width,height:height,child:labelWidget(item))])));
   }
  }
  final dir=await getTemporaryDirectory();final f=File('${dir.path}/SSOIL_etiketler.pdf');await f.writeAsBytes(await pdf.save());await Share.shareXFiles([XFile(f.path)]);
 }

 Widget reportsPage()=>ListView(children:[card('Etiket yazdırma',Column(children:[for(final e in labels.entries)ListTile(title:Text('${map(e.value)['name']}'),subtitle:Text('Šifra: ${e.key} • Cijena: ${money(map(e.value)['price'])} KM'),trailing:IconButton(onPressed:(){setState(()=>labels.remove(e.key));save();},icon:const Icon(Icons.close)))] ,),icon:Icons.label),card('Etiket kağıdı',Column(children:[RadioListTile<String>(title:const Text('A4'),value:'a4',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),RadioListTile<String>(title:const Text('9 etiketli sayfa • 3 × 3'),value:'sheet9',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),RadioListTile<String>(title:Text('Özel ölçü • ${labelWidthMm.toStringAsFixed(0)} × ${labelHeightMm.toStringAsFixed(0)} mm'),value:'custom',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),action('Tüm kağıtlarda ölçü ve boşluk ayarla',Icons.tune,editLabelDimensions)]),icon:Icons.print),FilledButton.icon(onPressed:printLabels,icon:const Icon(Icons.print),label:const Text('Etiket PDF oluştur')),const SizedBox(height:12),card('Excel Raporları',Wrap(spacing:8,runSpacing:8,children:[action('Tümünü Excel’e Aktar',Icons.file_download,exportAll),action('Tüm Ürünler',Icons.table_view,exportProducts),action('Siparişler (Tedarikçiye göre)',Icons.file_download,()=>exportOrders()),action('Eksik / Fazla',Icons.fact_check,exportDiscrepancies),action('Tedarikçiler',Icons.business,()=>exportCsv('SSOIL_TEDARIKCILER',[['Tedarikçi','Telefon'],...suppliers.values.map((e)=>[map(e)['name'],map(e)['phone']])])),action('Barkod Hataları',Icons.qr_code,()=>exportCsv('SSOIL_BARKOD_HATALARI',barcodeErrorRows())),action('Etiket Listesi',Icons.label,()=>exportCsv('SSOIL_ETIKETLER',[['Kod','Ürün','Barkod','Fiyat'],...labels.values.map((v){final p=map(v);return [p['id'],p['name'],barcode(p),p['price']];})]))]),icon:Icons.file_download),card('Satış kayıtları',Column(children:[for(final d in (daily.keys.toList()..sort()).reversed)metric(d,'${map(daily[d]).length} ürün')]),icon:Icons.bar_chart)]);
 Future<void> testSupabase()async{
  final url=supabaseUrl.trim().replaceAll(RegExp(r'/+$'),'');
  if(!url.startsWith('https://')||supabaseKey.trim().isEmpty){setState(()=>cloudStatus='URL veya publishable key eksik');return;}
  setState(()=>cloudStatus='Bağlantı test ediliyor...');
  try{
   final response=await http.get(Uri.parse('$url/auth/v1/health'),headers:{'apikey':supabaseKey.trim()}).timeout(const Duration(seconds:10));
   if(!mounted)return;
   setState(()=>cloudStatus=response.statusCode==200?'Supabase erişilebilir (veri eşitleme doğrulanmadı)':'Supabase yanıtı: HTTP ${response.statusCode}');
  }catch(e){if(mounted)setState(()=>cloudStatus='Bağlantı başarısız: $e');}
 }

 // Kullanici olusturma yalnizca Supabase Auth uzerinden yapilir.
 // Var olan oturum, PC baglantisi ve senkronizasyon donguleri degistirilmez.
 Future<void> addSupabaseUser() async {
  if(supabaseUrl.trim().isEmpty || supabaseKey.trim().isEmpty){
   notice('Önce Supabase URL ve publishable key tanımlayın');return;
  }
  final emailController=TextEditingController();
  final passwordController=TextEditingController();
  bool sending=false;
  try {
   await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,dialogSetState)=>AlertDialog(
    title:const Text('Yeni Kullanıcı Ekle'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     const Text('Yeni kullanıcı Supabase Auth hesabı olarak oluşturulur. E-posta doğrulaması proje ayarlarına bağlıdır.'),
     const SizedBox(height:12),
     TextField(controller:emailController,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'Kullanıcı e-postası')),
     const SizedBox(height:10),
     TextField(controller:passwordController,obscureText:true,decoration:const InputDecoration(labelText:'Şifre (en az 6 karakter)')),
    ])),
    actions:[
     TextButton(onPressed:sending?null:()=>Navigator.pop(dialogContext),child:const Text('İptal')),
     FilledButton(onPressed:sending?null:()async{
      final email=emailController.text.trim();final password=passwordController.text;
      if(!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)||password.length<6){
       ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content:Text('Geçerli e-posta ve en az 6 karakterli şifre girin')));return;
      }
      dialogSetState(()=>sending=true);
      try {
       final base=supabaseUrl.trim().replaceAll(RegExp(r'/+$'),'');
       final response=await http.post(Uri.parse('$base/auth/v1/signup'),headers:{
        'apikey':supabaseKey.trim(),'Content-Type':'application/json',
       },body:jsonEncode({'email':email,'password':password})).timeout(const Duration(seconds:12));
       if(!dialogContext.mounted)return;
       if(response.statusCode==200||response.statusCode==201){
        Navigator.pop(dialogContext);
        notice('Kayıt isteği kabul edildi. E-posta doğrulaması gerekebilir.');
       }else{
        String detail='HTTP ${response.statusCode}';
        try{final body=map(jsonDecode(response.body));detail='${body['msg']??body['message']??body['error_description']??detail}';}catch(_){}
        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text('Kullanıcı oluşturulamadı: $detail')));
       }
      }catch(e){if(dialogContext.mounted)ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text('Bağlantı hatası: $e')));}
      finally{if(dialogContext.mounted)dialogSetState(()=>sending=false);}
     },child:const Text('Kullanıcı Ekle')),
    ],
   )));
  }finally{Future<void>.delayed(const Duration(milliseconds:400),(){emailController.dispose();passwordController.dispose();});}
 }
 Widget settingsPage()=>ListView(children:[
  card('Kullanıcı Yönetimi',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('Supabase Auth üzerinden yeni kullanıcı hesabı oluşturun. Mevcut kullanıcı oturumu değiştirilmez.'),
   const SizedBox(height:10),
   FilledButton.icon(onPressed:addSupabaseUser,icon:const Icon(Icons.person_add_alt_1),label:const Text('Kullanıcı Ekle')),
  ]),icon:Icons.manage_accounts),
  card('Yakıt Alış Fiyatları',Column(children:[const Text('Benzin (1), Dizel (2), Dizel+ (3) • Supabase'),const SizedBox(height:10),FilledButton.icon(onPressed:editPurchasePrices,icon:const Icon(Icons.save),label:const Text('Alış Fiyatlarını Tanımla / Kaydet'))]),icon:Icons.local_gas_station),
  card('Bağlantılar',Column(children:[
   field('Yerel API adresi',local,(v)=>local=v),
   field('Bulut API adresi (isteğe bağlı, SS OIL köprüsü)',cloud,(v)=>cloud=v),
   field('API erişim tokeni',token,(v)=>token=v),
   field('Coffee To Go bağlantısı (sonra)',coffeeUrl,(v)=>coffeeUrl=v),
   field('Yakıt Art_ID listesi (virgülle)',fuelIds,(v)=>fuelIds=v),
   FilledButton(onPressed:()async{await save();notice('Ayarlar kaydedildi');},child:const Text('Kaydet'))
  ]),icon:Icons.settings_ethernet),
  card('Supabase Bulut Bağlantısı',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('PC ana merkezdir. Bu ayarlar yalnızca Supabase erişimini test eder; PC köprüsü ve telefon eşitlemesi ayrıca kurulmalıdır.'),
   const SizedBox(height:10),
   field('Supabase Project URL (https://...)',supabaseUrl,(v)=>supabaseUrl=v),
   field('Publishable / anon key (service_role DEĞİL)',supabaseKey,(v)=>supabaseKey=v),
   field('Supabase kullanıcı e-postası',supabaseEmail,(v)=>supabaseEmail=v),
   TextFormField(key:const ValueKey('ssoil_supabase_password_field'),obscureText:true,initialValue:supabasePassword,decoration:const InputDecoration(labelText:'Supabase kullanıcı şifresi (cihazda güvenli saklanır)'),onChanged:(v){supabasePassword=v;}),
   FilledButton(onPressed:()async{final ok=await cloudLogin();if(mounted)setState(()=>cloudStatus=ok?'Supabase kullanıcı girişi başarılı':'Supabase kullanıcı girişi başarısız');await save();},child:const Text('Bulut Veri Girişini Test Et')),
   const SizedBox(height:8),
   Text(cloudStatus),
   const SizedBox(height:8),
   Wrap(spacing:8,runSpacing:8,children:[
    OutlinedButton.icon(onPressed:()async{
      try {
        await secureStore.write(key:'ssoil_supabase_password',value:supabasePassword);
        final verified=await secureStore.read(key:'ssoil_supabase_password');
        if(verified!=supabasePassword)throw StateError('Sifre dogrulanamadi');
        await save();
        if(mounted)setState(()=>cloudStatus='Bulut ayarları ve şifre telefona kaydedildi');
        notice('Bulut ayarları ve şifre kaydedildi');
      } catch(e) {
        if(mounted)setState(()=>cloudStatus='Şifre kaydedilemedi: $e');
        notice('Şifre kaydedilemedi');
      }
    },icon:const Icon(Icons.save),label:const Text('Kaydet')),
    FilledButton.icon(onPressed:testSupabase,icon:const Icon(Icons.cloud_done),label:const Text('Bağlantıyı Test Et')),
   ]),
  ]),icon:Icons.cloud_outlined),
  card('Veri Temizleme',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('Silme öncesi onay alınır. PC bağlantısı başarısızsa silme değişikliği telefonda sıraya alınır; diğer cihazlara ulaştığı garanti değildir.'),
   const SizedBox(height:8),
   Wrap(spacing:8,runSpacing:8,children:[
    action('Etiketleri temizle',Icons.delete_sweep,()=>confirmClear('Etiketleri temizle?',()=>labels.clear())),
    action('Siparişleri temizle',Icons.delete_sweep,()=>confirmClear('Siparişleri temizle?',(){orders.clear();orderUnits.clear();})),
    action('Eksik/Fazla ve sayımı temizle',Icons.delete_sweep,()=>confirmClear('Eksik/Fazla ve sayım kayıtlarını temizle?',()=>discrepancies.clear())),
    action('Barkod hatalarını temizle',Icons.delete_sweep,()=>confirmClear('Barkod hatalarını temizle?',()=>barcodeErrors.clear())),
   ]),
   const SizedBox(height:8),
   const Text('Tedarikçi tanımları ve ürün–tedarikçi eşleşmeleri bu işlemlerle silinmez.'),
  ]),icon:Icons.delete_outline),
  card('Senkronizasyon Durumu',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   FilledButton.icon(
    onPressed:manualSyncing?null:syncAllManually,
    icon:const Icon(Icons.sync),
    label:Text(manualSyncing?'Eşitleniyor...':'Telefon ↔ PC + Supabase: Tümünü Eşitle'),
   ),
   const SizedBox(height:8),
   OutlinedButton.icon(onPressed:manualSyncing?null:syncCloudManually,icon:const Icon(Icons.cloud_sync),label:const Text('Telefon ↔ Supabase: Şimdi Eşitle')),
   const SizedBox(height:8),
  ]),icon:Icons.sync),
 ]);

 @override Widget build(BuildContext c){final Widget currentPage=switch(page){0=>homePage(),1=>kasaPage(),2=>stockPage(),3=>ordersPage(),4=>topPage(),5=>reportsPage(),6=>settingsPage(),7=>countPage(),8=>barcodeErrorsPage(),9=>ShiftPage(request:cloudRequest,kasa:kasa,kasaDate:day(selected)),_=>homePage()};final names=['Ana Sayfa','Kasa','Stok','Siparişler','Çok Satanlar','Raporlar','Ayarlar','Stok Sayım','Barkod Hataları','Vardiya'];final icons=[Icons.home_rounded,Icons.point_of_sale,Icons.inventory_2,Icons.shopping_cart,Icons.leaderboard,Icons.analytics,Icons.settings,Icons.fact_check,Icons.qr_code,Icons.account_balance_wallet];return Scaffold(appBar:AppBar(title:Row(children:[ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.asset('assets/ss_oil_logo.jpg',height:34,width:34,fit:BoxFit.contain)),const SizedBox(width:10),Expanded(child:Text('SS OIL • ${names[page]}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)))]),actions:[if(busy)const Padding(padding:EdgeInsets.all(14),child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))),IconButton(onPressed:()=>setState(()=>page=6),icon:const Icon(Icons.settings_outlined))]),body:Padding(padding:const EdgeInsets.all(12),child:KeyedSubtree(key:ValueKey<String>('ssoil-page-$page'),child:currentPage)),bottomNavigationBar:NavigationBar(height:70,backgroundColor:Theme.of(c).cardColor,selectedIndex:page<5?page:0,onDestinationSelected:(i)=>setState(()=>page=i),destinations:[for(var i=0;i<5;i++)NavigationDestination(icon:Icon(icons[i]),label:names[i])]),drawer:Drawer(child:SafeArea(child:ListView(children:[DrawerHeader(child:Image.asset('assets/ss_oil_logo.jpg',fit:BoxFit.contain)),for(var i=0;i<names.length;i++)ListTile(leading:Icon(icons[i],color:page==i?Theme.of(context).colorScheme.primary:null),title:Text(names[i]),selected:page==i,onTap:(){setState(()=>page=i);Navigator.pop(c);})]))));}
}
class Scanner extends StatefulWidget{final ValueChanged<String> onCode;const Scanner({super.key,required this.onCode});@override State<Scanner> createState()=>_ScannerState();}
class _ScannerState extends State<Scanner>{bool scanned=false;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Barkod Oku')),body:MobileScanner(onDetect:(capture){if(scanned)return;final code=capture.barcodes.firstOrNull?.rawValue;if(code!=null&&code.isNotEmpty){scanned=true;widget.onCode(code);}}));}
