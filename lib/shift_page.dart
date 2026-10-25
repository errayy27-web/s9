import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
typedef ShiftRequest = Future<http.Response?> Function(String method,String path,{Object? body,String? prefer});
class ShiftPage extends StatefulWidget {
 final ShiftRequest request;
 final Map<String,dynamic> kasa;
 final String kasaDate;
 final Map<String,dynamic> timedKasaHistory;
 final Map<String,dynamic> kasaArchive;
 const ShiftPage({super.key,required this.request,required this.kasa,required this.kasaDate,required this.timedKasaHistory,required this.kasaArchive});
 @override State<ShiftPage> createState()=>_ShiftPageState();
}
class _ShiftPageState extends State<ShiftPage> {
 Timer? timer; DateTime date=DateTime.now(); int shift=1; int section=0; String? detailKind; bool busy=false; String error=''; bool offline=false; DateTime? lastSync; List<Map<String,dynamic>> pendingWrites=[]; Map<String,dynamic> localHistory={};
 List<Map<String,dynamic>> transactions=[],options=[],banks=[],employees=[],handoffs=[],openings=[];
 Map<String,dynamic> daily={};
 String get dateKey=>date.toIso8601String().substring(0,10);
 Map<String,dynamic>? kasaAt(DateTime cutoff){
   final rows=(widget.timedKasaHistory[dateKey] as List?)??[];
   Map<String,dynamic>? selected;
   DateTime? last;
   for(final raw in rows){
     if(raw is! Map)continue;
     final item=Map<String,dynamic>.from(raw);
     final at=DateTime.tryParse('${item['at']??''}')?.toLocal();
     if(at==null||at.isAfter(cutoff)||last!=null&&at.isBefore(last))continue;
     final v=item['values'];
     if(v is Map){selected=Map<String,dynamic>.from(v);last=at;}
   }
   return selected;
 }

 num number(dynamic v)=>num.tryParse('$v'.replaceAll(',','.'))??0;
 String km(dynamic v)=>'${number(v).toStringAsFixed(2).replaceAll('.',',')} KM';
 List<Map<String,dynamic>> parse(String s)=>(jsonDecode(s) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
 @override void initState(){super.initState();loadLocal();timer=Timer.periodic(const Duration(seconds:3),(_)=>refresh());}
 @override void dispose(){timer?.cancel();super.dispose();}
 Future<void> loadLocal()async{
  final p=await SharedPreferences.getInstance();
  try{
   localHistory=Map<String,dynamic>.from(jsonDecode(p.getString('ssoil_shift_cache_v2')??'{}'));
   pendingWrites=(jsonDecode(p.getString('ssoil_shift_pending_v2')??'[]') as List).map((x)=>Map<String,dynamic>.from(x)).toList();
   restoreLocal();
  }catch(_){}
  await refresh();
 }
 void restoreLocal(){
  final d=localHistory[dateKey];if(d is! Map)return;
  if(!mounted)return;
  setState((){
   List<Map<String,dynamic>> rows(String k)=>((d[k] as List?)??[]).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   transactions=rows('transactions');options=rows('options');banks=rows('banks');employees=rows('employees');handoffs=rows('handoffs');openings=rows('openings');
   daily=Map<String,dynamic>.from((d['daily'] as Map?)??{});
  });
 }
 Future<void> persistLocal()async{
  localHistory[dateKey]={'transactions':transactions,'options':options,'banks':banks,'employees':employees,'handoffs':handoffs,'openings':openings,'daily':daily};
  final p=await SharedPreferences.getInstance();
  await p.setString('ssoil_shift_cache_v2',jsonEncode(localHistory));
  await p.setString('ssoil_shift_pending_v2',jsonEncode(pendingWrites));
 }
 Future<void> flushPending()async{
  if(pendingWrites.isEmpty)return;
  for(final op in List<Map<String,dynamic>>.from(pendingWrites)){
   try{
    final r=await widget.request(op['method'].toString(),op['table'].toString()+op['filter'].toString(),body:op['data'],prefer:'return=representation');
    if(r==null||r.statusCode<200||r.statusCode>=300||r.body.trim()=='[]')break;
    pendingWrites.remove(op);
    final p=await SharedPreferences.getInstance();
    await p.setString('ssoil_shift_pending_v2',jsonEncode(pendingWrites));
   }catch(_){break;}
  }
 }
 Future<List<Map<String,dynamic>>> fetch(String table,String filter)async{
  final r=await widget.request('GET',table+'?select=*&'+filter);
  if(r==null||r.statusCode!=200)throw Exception(r?.body??'Bağlantı yok');
  return parse(r.body);
 }
 bool autoClosing=false;
 String dateOf(DateTime d)=>d.toIso8601String().substring(0,10);
 Future<void> closePreviousDayFromArchive()async{
   if(autoClosing||offline||pendingWrites.isNotEmpty)return;
   final now=DateTime.now();
   if(dateKey!=dateOf(now))return;
   final previous=dateOf(now.subtract(const Duration(days:1)));
   final archived=widget.kasaArchive[previous];
   if(archived is! Map)return;
   final totals=Map<String,dynamic>.from(archived);
   if('${totals['date']??previous}'!=previous||totals['cash']==null||totals['card']==null||
       totals['mtel_dopuna']==null||totals['aero_dopuna']==null)return;
   autoClosing=true;
   try{
     final existing=await fetch('ssoil_shift_handoffs','business_date=eq.$previous&shift_number=eq.3');
     if(existing.isNotEmpty)return;
     final previousDaily=await fetch('ssoil_shift_daily','business_date=eq.$previous');
     final previousTransactions=await fetch('ssoil_shift_transactions','business_date=eq.$previous&deleted_at=is.null');
     final carry=previousDaily.isEmpty?0:number(previousDaily.first['cash_carryover']);
     num adjustment=0;
     for(final tx in previousTransactions){
       if(tx['kind']=='cash_collection')adjustment+=number(tx['amount']);
       if(tx['kind']=='cash_expense')adjustment-=number(tx['amount']);
     }
     final expected=carry+number(totals['cash'])+adjustment;
     final closed=DateTime(now.year,now.month,now.day).toUtc().toIso8601String();
     final payload={'business_date':previous,'shift_number':3,'employee_name':'3. Vardiya',
       'closed_at':closed,'expected_cash':expected,'delivered_cash':0,
       'status':'pending_delivery','snapshot':{
         'source':'archived_day_end_kasa','archive_date':previous,
         'cash':totals['cash'],'card':totals['card'],
         'cash_fuel':totals['cash_fuel'],'cash_market':totals['cash_market'],
         'mtel_dopuna':totals['mtel_dopuna'],'aero_dopuna':totals['aero_dopuna'],
         'fuel_sales':totals['fuel_sales'],'market_sales':totals['market_sales'],
         'delivered_pending':true}};
     await save('POST','ssoil_shift_handoffs',[payload]);
   }catch(_){/* Retry on the next successful refresh. */}
   finally{autoClosing=false;}
 }
 Future<void> carryPreviousThirdShift(Map<String,dynamic> record,num delivered)async{
   final today=dateOf(DateTime.now());
   final previous=dateOf(DateTime.now().subtract(const Duration(days:1)));
   if('${record['business_date']}'!=previous||number(record['shift_number'])!=3)return;
   final existing=await fetch('ssoil_shift_daily','business_date=eq.$today');
   final amount=double.parse(delivered.toStringAsFixed(2));
   if(existing.isEmpty){
     await save('POST','ssoil_shift_daily',[{'business_date':today,'cash_carryover':amount}]);
   }else{
     await save('PATCH','ssoil_shift_daily',{'cash_carryover':amount},
       filter:'?business_date=eq.$today&revision=eq.${existing.first['revision']}');
   }
 }
 Future<void> refresh()async{
  if(busy||!mounted)return;busy=true;
  try{
   await flushPending();
   if(pendingWrites.isNotEmpty){if(mounted)setState(()=>offline=true);return;}
   final v=await Future.wait([
    fetch('ssoil_shift_transactions','business_date=eq.'+dateKey+'&deleted_at=is.null&order=created_at.desc'),
    fetch('ssoil_shift_options','deleted_at=is.null&order=sort_order.asc'),
    fetch('ssoil_shift_banks','deleted_at=is.null&order=sort_order.asc'),
    fetch('ssoil_shift_employees','deleted_at=is.null&order=name.asc'),
    fetch('ssoil_shift_handoffs','business_date=eq.'+dateKey),
    fetch('ssoil_shift_daily','business_date=eq.'+dateKey),
    fetch('ssoil_shift_bank_opening','business_date=eq.'+dateKey)
   ]);
   if(mounted)setState((){transactions=v[0];options=v[1];banks=v[2];employees=v[3];handoffs=v[4];daily=v[5].isEmpty?{}:v[5].first;openings=v[6];error='';offline=false;lastSync=DateTime.now();});
   await persistLocal();
   if(dateKey==dateOf(DateTime.now()))Future.microtask(closePreviousDayFromArchive);
  }catch(e){if(mounted)setState((){error='Çevrimdışı: yerel kayıtlar gösteriliyor';offline=true;});}
  finally{busy=false;}
 }
 Future<void> save(String method,String table,Object? data,{String filter=''})async{
  if(busy)return;busy=true;
  final op=<String,dynamic>{'method':method,'table':table,'data':data,'filter':filter};
  try{
   final r=await widget.request(method,table+filter,body:data,prefer:'return=representation');
   if(r==null||r.statusCode<200||r.statusCode>=300||(method!='DELETE'&&r.body.trim()=='[]'))throw Exception(r?.body??'Bağlantı yok');
  }catch(e){
   pendingWrites.add(op);
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem çevrimdışı kuyruğa alındı. Bağlanınca gönderilecek.')));
  }finally{busy=false;await persistLocal();await refresh();}
 }
 List<String> labels(String code)=>options.where((x)=>x['list_code']==code).map((x)=>x['label'].toString()).toList();
 Future<void> editTransaction(String kind,[Map<String,dynamic>? old])async{
  String a=old?['first_value']?.toString()??'',b=old?['second_value']?.toString()??'',bank=old?['bank_id']?.toString()??'';
  final amount=TextEditingController(text:old?['amount']?.toString()??'');
  final desc=TextEditingController(text:old?['description']?.toString()??'');
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
   title:Text(old==null?'Yeni işlem':'İşlem düzenle'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:labels('T').contains(a)?a:null,isExpanded:true,decoration:const InputDecoration(labelText:'Kategori T'),items:labels('T').map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>change(()=>a=v??'')),
    DropdownButtonFormField<String>(value:labels('W').contains(b)?b:null,isExpanded:true,decoration:const InputDecoration(labelText:'Hesap W'),items:labels('W').map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>change(()=>b=v??'')),
    if(kind.startsWith('bank'))DropdownButtonFormField<String>(value:banks.any((v)=>v['id']==bank)?bank:null,isExpanded:true,decoration:const InputDecoration(labelText:'Banka Y'),items:banks.map((v)=>DropdownMenuItem(value:v['id'].toString(),child:Text(v['name'].toString()))).toList(),onChanged:(v)=>change(()=>bank=v??'')),
    TextField(controller:desc,decoration:const InputDecoration(labelText:'Açıklama')),
    TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Tutar KM')),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))])));
  if(ok!=true)return;
  final value=num.tryParse(amount.text.replaceAll(',','.'));
  if(a.isEmpty||b.isEmpty||value==null||value<0||(kind.startsWith('bank')&&bank.isEmpty)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Zorunlu alanları doldurun')));return;}
  final data={'business_date':dateKey,'shift_number':shift,'kind':kind,'first_value':a,'second_value':b,'bank_id':bank.isEmpty?null:bank,'amount':value,'description':desc.text};
  if(old==null){await save('POST','ssoil_shift_transactions',[data]);}
  else{await save('PATCH','ssoil_shift_transactions',data,filter:'?id=eq.'+old['id'].toString()+'&revision=eq.'+old['revision'].toString());}
 }
 Future<void> deleteTransaction(Map<String,dynamic> row)async{
  await save('PATCH','ssoil_shift_transactions',{'deleted_at':DateTime.now().toUtc().toIso8601String()},filter:'?id=eq.'+row['id'].toString()+'&revision=eq.'+row['revision'].toString());
 }
 Future<void> editNumber(String title,String table,String filter,Map<String,dynamic> data,String field,dynamic previous)async{
  final c=TextEditingController(text:number(previous??0).toStringAsFixed(2).replaceAll('.',','));
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))]));
  if(ok!=true)return;final value=num.tryParse(c.text.replaceAll(',','.'));if(value==null||value<0)return;
  data[field]=double.parse(value.toStringAsFixed(2));
  final exists=previous!=null;
  await save(exists?'PATCH':'POST',table,exists?{field:data[field]}:[data],filter:exists?filter:'');
 }
 num sum(String kind,{DateTime? until})=>transactions.where((v){
    if(v['kind']!=kind||v['shift_number']!=shift)return false;
    if(until==null)return true;
    final created=DateTime.tryParse('${v['created_at']??''}')?.toLocal();
    return created!=null&&!created.isAfter(until);
  }).fold<num>(0,(a,v)=>a+(num.tryParse(v['amount'].toString())??0));
 Future<void> handoff({Map<String,dynamic>? existing})async{
  final name=TextEditingController(text:existing==null?'':'${existing['employee_name']??''}');
  final delivered=TextEditingController(text:existing==null?'':'${existing['delivered_cash']??''}');
  final expectedEdit=TextEditingController(text:existing==null?'':'${existing['expected_cash']??''}');
  final now=DateTime.now();
  DateTime initial=now;
  if(existing!=null&&existing['closed_at']!=null){
    initial=DateTime.tryParse('${existing['closed_at']}')?.toLocal()??now;
  }
  final timeEdit=TextEditingController(text:'${initial.hour.toString().padLeft(2,'0')}:${initial.minute.toString().padLeft(2,'0')}:${initial.second.toString().padLeft(2,'0')}');
  final initialKasa=kasaAt(initial);
  final expectedAtStart=existing==null?number(daily['cash_carryover'])+number(initialKasa?['cash'])+sum('cash_collection',until:initial)-sum('cash_expense',until:initial):number(existing['expected_cash']);
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:Text(existing==null?'Vardiya Devri':'Vardiya Kaydını Düzelt'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Çalışan adı')),
      TextField(controller:delivered,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Teslim nakit KM')),
      if(existing!=null)TextField(controller:expectedEdit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Sabit beklenen nakit KM')),
      TextField(controller:timeEdit,decoration:const InputDecoration(labelText:'Vardiya işlem saati (SS:DD:SN)',helperText:'İlk kayıtta şu anki saat; sonra düzeltilebilir')),
      if(existing==null)Text(initialKasa==null?'Bu saate ait kasa örneği henüz yok':'Saatteki beklenen: ${km(expectedAtStart)}'),

    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))]));
  if(ok!=true)return;
  final parts=timeEdit.text.trim().split(':');
  if(parts.length!=3){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saat SS:DD:SN şeklinde olmalı')));return;}
  final hh=int.tryParse(parts[0]),mm=int.tryParse(parts[1]),ss=int.tryParse(parts[2]);
  if(hh==null||mm==null||ss==null||hh>23||hh<0||mm>59||mm<0||ss>59||ss<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geçersiz işlem saati')));return;}
  final localStamp=DateTime(date.year,date.month,date.day,hh,mm,ss);
  final closedAt=localStamp.toUtc().toIso8601String();
  final value=num.tryParse(delivered.text.replaceAll(',','.'));
  final fixed=existing==null?null:num.tryParse(expectedEdit.text.replaceAll(',','.'));
  if(value==null||name.text.trim().isEmpty||(existing!=null&&fixed==null))return;
  final timedKasa=kasaAt(localStamp);
  if(existing==null&&timedKasa==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bu saate ait kayıtlı kasa verisi yok. Yanlış toplam kaydedilmedi.')));return;}
  final expected=existing==null?number(daily['cash_carryover'])+number(timedKasa?['cash'])+sum('cash_collection',until:localStamp)-sum('cash_expense',until:localStamp):fixed!;
  final cashCollected=sum('cash_collection',until:localStamp),cashSpent=sum('cash_expense',until:localStamp);
  final bankCollected=sum('bank_collection',until:localStamp),bankSpent=sum('bank_expense',until:localStamp);
  final data=<String,dynamic>{'employee_name':name.text.trim(),'expected_cash':expected,'delivered_cash':value,'closed_at':closedAt};
  if(existing!=null&&number(existing['shift_number'])==3&&existing['status']=='pending_delivery')data['status']='closed';
  if(existing==null){
    data.addAll({'business_date':dateKey,'shift_number':shift,'status':'closed','closed_at':closedAt,
      'snapshot':{'cash_collection':cashCollected,'cash_expense':cashSpent,
        'bank_collection':bankCollected,'bank_expense':bankSpent,'recorded_at':closedAt,'kasa_at_close':timedKasa,'kasa_time_source':'pc_8767_sampled','kasa_time_note':'Son bilinen sayaç örneği; gerçek PR_Z işlem saati değildir'}});
    await save('POST','ssoil_shift_handoffs',[data]);
  }else{
    await save('PATCH','ssoil_shift_handoffs',data,filter:'?id=eq.${existing['id']}&revision=eq.${existing['revision']}');
    if(existing['status']=='pending_delivery')await carryPreviousThirdShift(existing,value);
  }
 }
 Future<void> deleteHandoff(Map<String,dynamic> record)async{
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
    title:const Text('Vardiya kaydını sil'),
    content:Text('${record['shift_number']}. vardiya kaydı silinsin mi?'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Sil'))]));
  if(ok!=true)return;
  await save('DELETE','ssoil_shift_handoffs',null,filter:'?id=eq.${record['id']}&revision=eq.${record['revision']}');
 }
 num total(String kind)=>transactions.where((v)=>v['kind']==kind).fold<num>(0,(a,v)=>a+number(v['amount']));
 num bankTotal(String kind,String id)=>transactions.where((v)=>v['kind']==kind&&v['bank_id'].toString()==id).fold<num>(0,(a,v)=>a+number(v['amount']));
 Widget line(String title,dynamic amount,{String? kind}){
  return ListTile(dense:true,title:Text(title),trailing:Row(mainAxisSize:MainAxisSize.min,children:[
   Text(km(amount)),if(kind!=null)TextButton(onPressed:()=>setState(()=>detailKind=kind),child:const Text('Göster'))
  ]));
 }
 Widget detail(){
  const names={'cash_expense':'Nakit Harcamalar','bank_expense':'Banka Harcamaları','cash_collection':'Nakit Tahsilatlar','bank_collection':'Banka Tahsilatları'};
  final rows=transactions.where((x)=>x['kind']==detailKind&&(section!=2||x['shift_number']==shift)).toList();
  return Column(children:[
   ListTile(title:Text(names[detailKind]??''),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>detailKind=null))),
   FilledButton.icon(onPressed:()=>editTransaction(detailKind!),icon:const Icon(Icons.add),label:const Text('Yeni Ekle')),
   for(final x in rows)Card(child:ListTile(title:Text(km(x['amount'])),subtitle:Text('${x['description']} / ${x['first_value']} / ${x['second_value']}'),trailing:Wrap(children:[
    IconButton(icon:const Icon(Icons.edit),onPressed:()=>editTransaction(detailKind!,x)),
    IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>deleteTransaction(x))
   ]))),
  ]);
 }
 Widget bankRows()=>Card(child:Column(children:[
  const ListTile(title:Text('BANKALAR — Açılış Bakiyeleri',style:TextStyle(fontWeight:FontWeight.bold))),
  for(final bank in banks)Builder(builder:(ctx){
   final rows=openings.where((v)=>v['bank_id']==bank['id']).toList();
   final opening=rows.isEmpty?null:rows.first['opening_balance'];
   final id=bank['id'].toString();
   return Column(children:[
    ListTile(title:Text(bank['name'].toString()),subtitle:Text('Açılış: ${km(opening)} • Güncel: ${km(number(opening)+bankTotal('bank_collection',id)-bankTotal('bank_expense',id))}'),trailing:IconButton(icon:const Icon(Icons.edit),onPressed:()=>editNumber('Banka açılış','ssoil_shift_bank_opening','?business_date=eq.$dateKey&bank_id=eq.$id',{'business_date':dateKey,'bank_id':id},'opening_balance',opening))),
    line('Banka tahsilatları',bankTotal('bank_collection',id),kind:'bank_collection'),
    line('Banka harcamaları',bankTotal('bank_expense',id),kind:'bank_expense'),
   ]);
  })
 ]));
 Widget summary()=>Column(children:[
  Card(child:Column(children:[
   const ListTile(title:Text('GÜNLÜK KASA ÖZETİ',style:TextStyle(fontWeight:FontWeight.bold))),
   ListTile(title:const Text('Gün başı nakit devir'),subtitle:Text(km(daily['cash_carryover'])),trailing:IconButton(icon:const Icon(Icons.edit),onPressed:()=>editNumber('Nakit devir','ssoil_shift_daily','?business_date=eq.$dateKey',{'business_date':dateKey},'cash_carryover',daily['cash_carryover']))),
   line('Nakit yakıt',widget.kasa['cash_fuel']),
   line('Nakit market',widget.kasa['cash_market']),
   line('MTEL',widget.kasa['mtel_dopuna']),
   line('AERO',widget.kasa['aero_dopuna']),
   line('Nakit tahsilatlar',total('cash_collection'),kind:'cash_collection'),
   line('TOPLAM NAKİT',number(daily['cash_carryover'])+number(widget.kasa['cash'])+total('cash_collection')),
   line('Nakit harcamalar',total('cash_expense'),kind:'cash_expense'),
   Row(children:[
    Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[const Text('Olması Gereken Nakit'),Text(km(number(daily['cash_carryover'])+number(widget.kasa['cash'])+total('cash_collection')-total('cash_expense')),style:const TextStyle(fontWeight:FontWeight.bold))])))),
    Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[const Text('Kredi Kartı'),Text(km(widget.kasa['card']),style:const TextStyle(fontWeight:FontWeight.bold))]))))
   ]),
  ])),
  bankRows(),
  const Card(child:ListTile(title:Text('Gün Sonu Tutarları'),subtitle:Text('Nakit, kredi kartı ve banka gün sonu kayıtları ayrıca eklenecek.'))),
 ]);
 Widget handoffPage()=>Column(children:[
  Wrap(spacing:8,children:[for(var i=1;i<=3;i++)ChoiceChip(label:Text('$i. Vardiya'),selected:shift==i,onSelected:(_)=>setState(()=>shift=i))]),
  line('Nakit tahsilatlar',sum('cash_collection'),kind:'cash_collection'),
  line('Nakit harcamalar',sum('cash_expense'),kind:'cash_expense'),
  line('Nakit yakıt + market',number(widget.kasa['cash_fuel'])+number(widget.kasa['cash_market'])),
  line('MTEL + AERO',number(widget.kasa['mtel_dopuna'])+number(widget.kasa['aero_dopuna'])),
  line('Kredi Kartı',widget.kasa['card']),
  FilledButton.icon(onPressed:handoff,icon:const Icon(Icons.check),label:const Text('Vardiya Devri Kaydet')),
  for(final h in handoffs)ListTile(onTap:()=>handoff(existing:h),title:Text('${h['shift_number']}. Vardiya - ${h['employee_name']}'),subtitle:Text('Teslim: ${km(h['delivered_cash'])} / Beklenen: ${km(h['expected_cash'])}\\n${h['closed_at']??''}'),trailing:Wrap(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:const Icon(Icons.edit),onPressed:()=>handoff(existing:h)),IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>deleteHandoff(h))])),
 ]);
 @override Widget build(BuildContext context){
  return ListView(children:[
   Row(children:[Expanded(child:OutlinedButton.icon(icon:const Icon(Icons.calendar_month),label:Text(dateKey),onPressed:()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null){setState(()=>date=d);restoreLocal();refresh();}})),IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]),
   if(offline)const ListTile(leading:Icon(Icons.wifi_off),title:Text('Çevrimdışı — kayıtlar telefonda saklanıyor')),
   if(pendingWrites.isNotEmpty)Text('${pendingWrites.length} işlem senkronizasyon bekliyor'),
   if(lastSync!=null)Text('Son senkronizasyon: ${lastSync!.hour.toString().padLeft(2,'0')}:${lastSync!.minute.toString().padLeft(2,'0')}'),
   if(section!=0)TextButton.icon(onPressed:()=>setState((){section=0;detailKind=null;}),icon:const Icon(Icons.arrow_back),label:const Text('Vardiya Yönetimi')),
   if(section==0)...[
    const ListTile(title:Text('VARDİYA YÖNETİMİ',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
    line('Anlık olması gereken nakit',number(daily['cash_carryover'])+number(widget.kasa['cash'])+total('cash_collection')-total('cash_expense')),
    line('Kredi kartı',widget.kasa['card']),
    for(final k in ['cash_expense','bank_expense','cash_collection','bank_collection'])
     OutlinedButton(onPressed:()=>setState(()=>detailKind=k),child:Text({'cash_expense':'Nakit Harcamalar','bank_expense':'Banka Harcamaları','cash_collection':'Nakit Tahsilatlar','bank_collection':'Banka Tahsilatları'}[k]!)),
    FilledButton(onPressed:()=>setState(()=>section=1),child:const Text('1. Bölüm — Günlük Kasa ve Bankalar')),
    FilledButton(onPressed:()=>setState(()=>section=2),child:const Text('2. Bölüm — Vardiya Devri')),
   ],
   if(section==1)summary(),
   if(section==2)handoffPage(),
   if(detailKind!=null)detail(),
  ]);
 }
}
