import 'alert_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';
import 'startpage.dart';
import 'session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:wakelock/wakelock.dart';
//import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter_blue/flutter_blue.dart';

const COMMUNICATION_UUID = '0f3d3165-9567-4693-b5ec-7932d6e634a5';

void main() => runApp(MyApp());

SharedPreferences sharedPreferences;
Dio dio;

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COVID-19 Tracker',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: StartPage(),
    );
  }
}

class IndexPage extends StatefulWidget {

  @override
  _IndexPageState createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {

  int index = 0;
  List<Widget> pages = [BroadcastPage(), SessionsPage(), AlertPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.speaker_phone),
            title: Text('Go Out'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            title: Text('Sessions'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            title: Text('Alerts')
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ]
      ),
    );
  }
}

class BroadcastPage extends StatefulWidget {
  BroadcastPage({Key key}) : super(key: key);
  @override
  _BroadcastPageState createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {

  bool _scanning = false;
  bool _shouldStop = true;
  bool _sendingData = false;
  String _error = '';
  Session currentSession;
//  BeaconBroadcast beaconBroadcast;
  FlutterBlue flutterBlue;

  @override
  void initState() {

    super.initState();

    currentSession = Session();
//    beaconBroadcast = BeaconBroadcast();
    flutterBlue = FlutterBlue.instance;
    var subscription = flutterBlue.scanResults;


    subscription.listen((results) {
      // do something with scan results
      for (ScanResult r in results) {
        debugPrint('${r.device.name} found! rssi: ${r.rssi}, localname: ${r.advertisementData.localName}');
      }
    });
  }

  void sendSession() async {

    setState(() {
      _sendingData = true;
    });
    try {
      await currentSession.send();
      if(currentSession.deviceIds.length == 0) {
        setState(() {
          _error = '';
          _sendingData = false;
        });
      }
      debugPrint('success');
      setState(() {
        _error = '';
        _sendingData = false;
        List<String> strTimes = List();
        currentSession.times.forEach((t) {
          strTimes.add(DateFormat('hh:mm a MM-dd-yyyy').format(t.toLocal()));
        });
        int sessions = (sharedPreferences.getInt('sessions') ?? 0) + 1;
        sharedPreferences.setStringList('ids_$sessions', currentSession.deviceIds);
        sharedPreferences.setStringList('times_$sessions', strTimes);
        sharedPreferences.setInt('sessions', sessions);
        currentSession = Session();
      });
    } catch(e) {
      debugPrint('not success');
      setState(() {
        _sendingData = false;
        _error = 'There\'s been an error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('error is $_error, ${_error != ''}');
    return new Scaffold(
      appBar: new AppBar(
        title: Text('New Session'),
      ),
      body: _error != '' ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_error),
            RaisedButton(
              child: Text('Retry'),
              onPressed: () {
                sendSession();
              },
            )
          ],
        ),
      ) : _sendingData ? Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Spacer(),
            _scanning && currentSession.deviceIds.length > 0 ? Center(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currentSession.deviceIds.length,
                itemBuilder: (ctx, index) {
                  return Text('Connected to device COVID19-${currentSession.deviceIds[index]} on ${DateFormat('hh:mm a MM-dd-yyyy').format(currentSession.times[index].toLocal())}.', textAlign: TextAlign.center,);
                },
              ),
            ) : _scanning ? Text('No devices yet.') : Text('Press the start session button whenever you\'re out, and press stop when you return home. Do not close this app during the session for proper function'),
            Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: RaisedButton(child: Text(_scanning ? 'Stop session' : 'Start session'), onPressed: () async {
                  debugPrint('3: $_shouldStop && $_scanning');
                  try {
                    if(_scanning) {
                      _shouldStop = true;
                      await Wakelock.disable();
                      await flutterBlue.stopScan();

//                      await beaconBroadcast.stop();
                      _scanning = false;
                      sendSession();
                    }
                    else {
                      await Wakelock.enable();
                      await flutterBlue.startScan(
                          withServices: [
                            Guid(COMMUNICATION_UUID),
                          ],
                          timeout: Duration(seconds: 60)
                      );

                      var subscription = flutterBlue.scanResults.listen((results) {
                        // do something with scan results
                        for (ScanResult r in results) {
                          print('${r.device.name} found! rssi: ${r.rssi}');
                        }
                      });

//                      await beaconBroadcast
//                          .setUUID('39ED98FF-2900-441A-802F-9C398FC199D2')
//                          .setMajorId(1)
//                          .setMinorId(100)
//                          .setTransmissionPower(-59) //optional
//                          .setIdentifier('COVID19-1')
////                          .setIdentifier('com.example.myDeviceRegion') //iOS-only, optional
////                          .setLayout('s:0-1=feaa,m:2-2=10,p:3-3:-41,i:4-21v') //Android-only, optional
////                          .setManufacturerId(0x001D) //Android-only, optional
//                          .start();
//                      beaconBroadcast.getAdvertisingStateChange().listen((isAdvertising) {
//                        debugPrint('is ADVERTISTING: $isAdvertising');
//                      });
                      debugPrint("scanning started");
                      _shouldStop = false;
                      setState(() {
                        _scanning = true;
                      });
                    }
                  } on PlatformException catch (e) {
                    debugPrint(e.toString());
                  }
                }),
              ),
            )
          ],
        ),
      ),
    );
  }
}