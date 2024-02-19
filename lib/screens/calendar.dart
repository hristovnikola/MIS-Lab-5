import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/Exam.dart';
import '../widgets/authentication.dart';
import '../widgets/add_new.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CollectionReference _itemsCollection =
      FirebaseFirestore.instance.collection('exams');
  List<Exam> _exams = [];
  Map<DateTime, List<dynamic>> _events = {};
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await _itemsCollection
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get() as QuerySnapshot<Map<String, dynamic>>;

    _exams =
        querySnapshot.docs.map((DocumentSnapshot<Map<String, dynamic>> doc) {
      return Exam.fromMap(doc.data()!);
    }).toList();
    _updateEvents();
  }

  void _updateEvents() {
    _events = {};
    for (Exam exam in _exams) {
      DateTime examDate =
          DateTime(exam.date.year, exam.date.month, exam.date.day, 0, 0, 0);
      if (_events.containsKey(examDate)) {
        _events[examDate]!.add(exam);
      } else {
        _events[examDate] = [exam];
      }
    }
    setState(() {});
  }

  void _addExam() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: NewExam(
            addExam: _addNewExamToDatabase,
          ),
        );
      },
    );
  }

  void _addNewExamToDatabase(
      String subject, DateTime date, TimeOfDay time) async {
    String topic = 'exams';
    FirebaseMessaging.instance.subscribeToTopic(topic);
    try {
      var deviceState = await OneSignal.shared.getDeviceState();
      String? playerId = deviceState?.userId;
      if (playerId != null && playerId.isNotEmpty) {
        List<String> playerIds = [playerId];
        try {
          await OneSignal.shared.postNotification(OSCreateNotification(
            playerIds: playerIds,
            content: "You have a new exam: $subject",
            heading: "New Exam Added",
          ));
        } catch (e) {}
      } else {}
    } catch (e) {}
    addExam(subject, date, time);
  }

  Future<void> addExam(String subject, DateTime date, TimeOfDay time) async {
    User? user = FirebaseAuth.instance.currentUser;
    DateTime newDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute, 0, 0, 0);
    if (user != null) {
      await FirebaseFirestore.instance.collection('exams').add({
        'subject': subject,
        'date': newDate,
        'userId': user.uid,
      });
      _loadExams();
    }
  }

  Future<void> _signOutAndNavigateToLogin(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AuthGate()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nikola Hristov, 201097"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          ElevatedButton(
            onPressed: () => _addExam(),
            style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll<Color>(
                  Color.fromRGBO(49, 49, 131, 1)),
            ),
            child: const Text(
              "Add exam",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => _signOutAndNavigateToLogin(context),
            style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll<Color>(
                  Color.fromRGBO(42, 147, 209, 1)),
            ),
            child: const Text(
              "Sign out",
              style: TextStyle(
                  color: Color.fromRGBO(49, 49, 131, 1),
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2022),
            lastDay: DateTime(2025),
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerStyle: HeaderStyle(
              formatButtonTextStyle:
                  TextStyle().copyWith(color: Colors.white, fontSize: 15.0),
              formatButtonDecoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            calendarStyle: CalendarStyle(
              weekendTextStyle: TextStyle().copyWith(color: Colors.yellow),
              outsideDaysVisible: false,
              markersMaxCount: 1,
              markersAlignment: Alignment.bottomCenter,
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(
                  color: Color.fromRGBO(55, 220, 214, 1),
                  width: 2,
                ),
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(
                  color: Color.fromRGBO(55, 220, 214, 1),
                  width: 2,
                ),
              ),
            ),
            onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (DateTime focusedDay) {
              setState(() {
                _focusedDay = DateTime(focusedDay.year, focusedDay.month, 1);
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                DateTime eventDate = DateTime(date.year, date.month, date.day);
                if (_events.containsKey(eventDate) &&
                    _events[eventDate]!.isNotEmpty) {
                  return Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.yellow,
                      ),
                      width: 20.0,
                      height: 20.0,
                      child: Center(
                        child: Text(
                          _events[eventDate]!.length.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildExamList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExamList() {
    final currentMonthExams = _exams
        .where((exam) =>
            exam.date.month == _focusedDay.month &&
            exam.date.year == _focusedDay.year)
        .toList();

    if (currentMonthExams.isEmpty) {
      return const Center(
        child: Text("No exams for the current month."),
      );
    }

    return GridView.builder(
      itemCount: currentMonthExams.length,
      itemBuilder: (context, index) {
        return Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentMonthExams[index].subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(currentMonthExams[index].date),
                    style: const TextStyle(fontSize: 20, color: Colors.grey),
                  )
                ],
              )
            ],
          ),
        );
      },
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
    );
  }
}
