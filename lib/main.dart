// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusMateApp());
}

class CampusMateApp extends StatelessWidget {
  const CampusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamilyFallback: const ["Hiragino Sans", "Noto Sans JP", "Meiryo", "sans-serif"],
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      home: const HomePage(),
    );
  }
}

enum TaskType { assignment, job, private }

class Task {
  String id;
  String title;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  TaskType type;
  Color color;
  String? subject;
  bool hasLabel;
  String? workplace;
  String? details;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.color,
    this.subject,
    this.hasLabel = false,
    this.workplace,
    this.details,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
    'type': type.index,
    'color': color.value,
    'subject': subject,
    'hasLabel': hasLabel,
    'workplace': workplace,
    'details': details,
    'isCompleted': isCompleted,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      startTime: TimeOfDay(hour: json['startHour'], minute: json['startMinute']),
      endTime: TimeOfDay(hour: json['endHour'], minute: json['endMinute']),
      type: TaskType.values[json['type']],
      color: Color(json['color']),
      subject: json['subject'],
      hasLabel: json['hasLabel'] ?? false,
      workplace: json['workplace'],
      details: json['details'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class ClassPeriod {
  String subject;
  String room;
  String teacher;
  int dayOfWeek;
  int period;
  int attended; 
  int absent;   
  int late;     
  
  ClassPeriod(this.subject, this.room, this.teacher, this.dayOfWeek, this.period, {
    this.attended = 0, this.absent = 0, this.late = 0
  });

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'room': room,
    'teacher': teacher,
    'dayOfWeek': dayOfWeek,
    'period': period,
    'attended': attended,
    'absent': absent,
    'late': late,
  };

  factory ClassPeriod.fromJson(Map<String, dynamic> json) => ClassPeriod(
    json['subject'],
    json['room'],
    json['teacher'],
    json['dayOfWeek'],
    json['period'],
    attended: json['attended'] ?? 0,
    absent: json['absent'] ?? 0,
    late: json['late'] ?? 0,
  );
}

enum CalendarViewMode { month, week, day }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _currentDate = DateTime.now();
  int _footerIndex = 0; 
  CalendarViewMode _viewMode = CalendarViewMode.month;

  String _assignmentSort = 'deadline'; 
  String _jobSort = 'date';
  bool _filterImportantOnly = false;

  List<Task> _allTasks = [];
  List<ClassPeriod> _timetable = [];
  List<String> _workplaces = ['セブンイレブン', 'スタバ']; 

  // 通知設定
  bool _notifyAssignment = true;
  int _notifyAssignmentMins = 60; 
  bool _notifyJob = true;
  int _notifyJobMins = 120;
  bool _notifyPrivate = true;
  int _notifyPrivateMins = 30;

  List<Map<String, String>> _periodSettings = [
    {"name": "1限", "start": "08:40", "end": "10:20"},
    {"name": "2限", "start": "10:35", "end": "12:15"},
    {"name": "3限", "start": "13:15", "end": "14:55"},
    {"name": "4限", "start": "15:10", "end": "16:50"},
    {"name": "5限", "start": "17:05", "end": "18:45"},
  ];

  final Map<TaskType, Color> _typeColors = {
    TaskType.assignment: Colors.blue.shade600,
    TaskType.job: Colors.amber.shade700,
    TaskType.private: Colors.green.shade600,
  };
  final Map<TaskType, Color> _typeBgColors = {
    TaskType.assignment: Colors.blue.shade200,
    TaskType.job: Colors.amber.shade200,
    TaskType.private: Colors.green.shade200,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = _allTasks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('tasks', tasksJson);
      final timetableJson = _timetable.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('timetable', timetableJson);
      await prefs.setStringList('workplaces', _workplaces);
      final settingsJson = jsonEncode(_periodSettings);
      await prefs.setString('periodSettings', settingsJson);
      
      await prefs.setBool('notifyAssignment', _notifyAssignment);
      await prefs.setInt('notifyAssignmentMins', _notifyAssignmentMins);
      await prefs.setBool('notifyJob', _notifyJob);
      await prefs.setInt('notifyJobMins', _notifyJobMins);
      await prefs.setBool('notifyPrivate', _notifyPrivate);
      await prefs.setInt('notifyPrivateMins', _notifyPrivateMins);
    } catch (e) {
      debugPrint("Save Error: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        final tasksList = prefs.getStringList('tasks');
        if (tasksList != null) {
          _allTasks = tasksList.map((t) => Task.fromJson(jsonDecode(t))).toList();
        }
        final timetableList = prefs.getStringList('timetable');
        if (timetableList != null) {
          _timetable = timetableList.map((t) => ClassPeriod.fromJson(jsonDecode(t))).toList();
        }
        final wpList = prefs.getStringList('workplaces');
        if (wpList != null) {
          _workplaces = wpList;
        }
        final settingsString = prefs.getString('periodSettings');
        if (settingsString != null) {
          List<dynamic> decoded = jsonDecode(settingsString);
          _periodSettings = decoded.map((e) => Map<String, String>.from(e)).toList();
        }
        _notifyAssignment = prefs.getBool('notifyAssignment') ?? true;
        _notifyAssignmentMins = prefs.getInt('notifyAssignmentMins') ?? 60;
        _notifyJob = prefs.getBool('notifyJob') ?? true;
        _notifyJobMins = prefs.getInt('notifyJobMins') ?? 120;
        _notifyPrivate = prefs.getBool('notifyPrivate') ?? true;
        _notifyPrivateMins = prefs.getInt('notifyPrivateMins') ?? 30;
      });
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  Future<void> _resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _allTasks = [];
      _timetable = [];
      _workplaces = ['セブンイレブン', 'スタバ'];
    });
    _saveData(); 
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  
  List<String> _getSubjectsFromTimetable() {
    final list = _timetable.map((e) => e.subject).toSet().toList();
    list.add("その他");
    return list;
  }

  List<Task> _checkOverlap(DateTime date, TimeOfDay start, TimeOfDay end, TaskType type, {String? excludeId}) {
    final newStartMins = start.hour * 60 + start.minute;
    final newEndMins = end.hour * 60 + end.minute;

    return _allTasks.where((t) {
      if (t.id == excludeId) return false;
      if (!isSameDay(t.date, date)) return false;
      if (t.isCompleted) return false;
      if (type == TaskType.assignment && t.type == TaskType.assignment) return false;

      final tStartMins = t.startTime.hour * 60 + t.startTime.minute;
      final tEndMins = t.endTime.hour * 60 + t.endTime.minute;
      return (newStartMins < tEndMins && newEndMins > tStartMins);
    }).toList();
  }

  Color _getCurrentThemeColor() {
    if (_footerIndex == 2) return Colors.blue.shade100;
    if (_footerIndex == 3) return Colors.amber.shade100;
    if (_footerIndex == 4) return Colors.green.shade100;
    return Colors.grey.shade50;
  }
  
  Color _getCurrentHeaderColor() {
    if (_footerIndex == 2) return Colors.blue;
    if (_footerIndex == 3) return Colors.amber;
    if (_footerIndex == 4) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(), 
      body: _buildBody(),
      floatingActionButton: (_footerIndex == 1 || (_footerIndex == 0 && _viewMode == CalendarViewMode.month)) 
          ? null 
          : FloatingActionButton(
              onPressed: () => _showAddEditTaskDialog(),
              backgroundColor: _getCurrentHeaderColor(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: Container(
        color: _getCurrentThemeColor(),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: Colors.white54,
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _footerIndex,
            height: 65,
            onDestinationSelected: (index) => setState(() => _footerIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'すべて'),
              NavigationDestination(icon: Icon(Icons.grid_view), label: '時間割'),
              NavigationDestination(icon: Icon(Icons.assignment), label: '課題'),
              NavigationDestination(icon: Icon(Icons.currency_yen), label: 'バイト'),
              NavigationDestination(icon: Icon(Icons.face), label: '私用'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('CampusMate 設定', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar),
            title: const Text('時間割の登録・修正'),
            subtitle: const Text('科目や教室の変更はこちら'),
            onTap: () { 
              Navigator.pop(context); 
              _navigateToTimetableEditor(); 
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('時間割の時間設定'),
            onTap: () { Navigator.pop(context); _showTimeSettingDialog(); },
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('バイト先管理'),
            onTap: () { Navigator.pop(context); _showManageWorkplacesDialog(); },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知設定'),
            onTap: () { Navigator.pop(context); _showNotificationSettings(); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('全データをリセット', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showResetConfirmDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('⚠️ データの完全削除'),
      content: const Text('この操作は取り消せません。\n登録したすべての予定、時間割、設定が削除されます。\n本当によろしいですか？'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('キャンセル')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await _resetAllData();
            if(!mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('すべてのデータを削除しました')));
          }, 
          child: const Text('削除する')
        ),
      ],
    ));
  }

  AppBar _buildAppBar() {
    Color bgColor = _getCurrentHeaderColor();
    Color textColor = Colors.white;

    Widget? leading = Builder(
      builder: (context) => IconButton(
        icon: Icon(Icons.menu, color: (_footerIndex==1) ? Colors.black : Colors.white),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );

    if (_footerIndex == 1) {
      return AppBar(
        title: const Text('時間割', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: leading, 
        iconTheme: const IconThemeData(color: Colors.black),
      );
    }
    
    if (_footerIndex > 1) {
      String title = _footerIndex == 2 ? '課題一覧' : (_footerIndex == 3 ? 'バイトシフト' : '私用');
      return AppBar(
        title: Text(title, style: TextStyle(color: textColor)), 
        backgroundColor: bgColor,
        leading: leading, 
        iconTheme: IconThemeData(color: textColor),
        actions: [_buildSortButton(textColor)]
      );
    }

    return AppBar(
      title: const Text('カレンダー', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.blue,
      leading: leading,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CupertinoSegmentedControl<CalendarViewMode>(
            groupValue: _viewMode,
            borderColor: Colors.white,
            selectedColor: Colors.white,
            unselectedColor: Colors.blue,
            pressedColor: Colors.blue.shade200,
            children: const {
              CalendarViewMode.month: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('月', style: TextStyle(color: Colors.black))),
              CalendarViewMode.week: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('週', style: TextStyle(color: Colors.black))),
              CalendarViewMode.day: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('日', style: TextStyle(color: Colors.black))),
            },
            onValueChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ),
      ),
      actions: [IconButton(icon: const Icon(Icons.today, color: Colors.white), onPressed: () => setState(() => _currentDate = DateTime.now()))],
    );
  }

  Widget _buildSortButton(Color color) {
    if (_footerIndex == 2 || _footerIndex == 3) {
      return Row(
        children: [
          if(_footerIndex == 2) IconButton(
            icon: Icon(_filterImportantOnly ? Icons.label : Icons.label_outline, color: color),
            tooltip: '重要のみ表示',
            onPressed: () => setState(() => _filterImportantOnly = !_filterImportantOnly),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: color), 
            onSelected: (val) {
               if(_footerIndex == 2) setState(() => _assignmentSort = val);
               if(_footerIndex == 3) setState(() => _jobSort = val);
            },
            itemBuilder: (context) {
               if(_footerIndex == 2) {
                 return const [PopupMenuItem(value: 'deadline', child: Text('提出日順')), PopupMenuItem(value: 'subject', child: Text('科目順'))];
               } else {
                 return const [PopupMenuItem(value: 'date', child: Text('日付順')), PopupMenuItem(value: 'workplace', child: Text('バイト先別'))];
               }
            },
          ),
        ],
      );
    } 
    return const SizedBox.shrink();
  }

  void _selectTime(BuildContext context, TimeOfDay initial, Function(TimeOfDay) onSelected, {int minuteInterval = 1}) {
    final now = DateTime.now();
    final initialDateTime = DateTime(now.year, now.month, now.day, initial.hour, initial.minute);

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initialDateTime,
                use24hFormat: true,
                minuteInterval: minuteInterval,
                onDateTimeChanged: (val) {
                  onSelected(TimeOfDay(hour: val.hour, minute: val.minute));
                },
              ),
            ),
            CupertinoButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop())
          ],
        ),
      ),
    );
  }

  void _showNotificationTimePicker(int initialMinutes, Function(int) onSelected) {
    final items = List.generate(25, (index) => index * 5); 
    if(!items.contains(initialMinutes)) items.add(initialMinutes);
    items.sort();
    
    int selectedIndex = items.indexOf(initialMinutes);
    if(selectedIndex < 0) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                onSelectedItemChanged: (i) => selectedIndex = i,
                children: items.map((m) => Center(child: Text("$m 分前"))).toList(),
              ),
            ),
            CupertinoButton(
              child: const Text('決定'),
              onPressed: () {
                onSelected(items[selectedIndex]);
                Navigator.of(context).pop();
              },
            )
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text('通知設定'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("※通知内容: [種類] [時間] [内容]", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            SwitchListTile(title: const Text('課題の通知'), value: _notifyAssignment, onChanged: (v){ setDialogState((){ _notifyAssignment=v; }); _saveData(); }),
            if(_notifyAssignment) ListTile(title: const Text("通知タイミング"), trailing: Text("$_notifyAssignmentMins 分前", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onTap: () => _showNotificationTimePicker(_notifyAssignmentMins, (m){ setDialogState(()=>_notifyAssignmentMins=m); _saveData(); })),
            const Divider(),
            SwitchListTile(title: const Text('バイトの通知'), value: _notifyJob, onChanged: (v){ setDialogState((){ _notifyJob=v; }); _saveData(); }),
            if(_notifyJob) ListTile(title: const Text("通知タイミング"), trailing: Text("$_notifyJobMins 分前", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onTap: () => _showNotificationTimePicker(_notifyJobMins, (m){ setDialogState(()=>_notifyJobMins=m); _saveData(); })),
            const Divider(),
            SwitchListTile(title: const Text('私用の通知'), value: _notifyPrivate, onChanged: (v){ setDialogState((){ _notifyPrivate=v; }); _saveData(); }),
            if(_notifyPrivate) ListTile(title: const Text("通知タイミング"), trailing: Text("$_notifyPrivateMins 分前", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onTap: () => _showNotificationTimePicker(_notifyPrivateMins, (m){ setDialogState(()=>_notifyPrivateMins=m); _saveData(); })),
          ]),
        ),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('閉じる'))],
      );
    }));
  }

  void _navigateToTimetableEditor() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => TimetableEditorPage(
        periodSettings: _periodSettings,
        timetable: _timetable,
        onSave: (newTimetable) {
          setState(() { _timetable = newTimetable; });
          _saveData();
        },
      ),
    ));
  }

  Widget _buildBody() {
    if (_footerIndex == 1) return _buildTimetableView();
    if (_footerIndex > 1) {
      TaskType type = _footerIndex == 2 ? TaskType.assignment : (_footerIndex == 3 ? TaskType.job : TaskType.private);
      return _buildTaskListView(_getFilteredAndSortedTasks(type));
    }
    return Column(
      children: [
        _buildDateControlBar(),
        Expanded(
          child: _viewMode == CalendarViewMode.month
              ? _buildMonthView()
              : _viewMode == CalendarViewMode.week
                  ? _buildWeekView()
                  : _buildDayView(),
        ),
      ],
    );
  }

  List<Task> _getFilteredAndSortedTasks(TaskType type) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));

    List<Task> tasks = _allTasks.where((t) {
      if (t.type != type) return false;
      DateTime taskDate = DateTime(t.date.year, t.date.month, t.date.day);
      return !taskDate.isBefore(yesterday);
    }).toList();

    if (_filterImportantOnly && type == TaskType.assignment) {
      tasks = tasks.where((t) => t.hasLabel).toList();
    }

    if (type == TaskType.assignment) {
      if (_assignmentSort == 'deadline') tasks.sort((a, b) => a.date.compareTo(b.date));
      if (_assignmentSort == 'subject') tasks.sort((a, b) => (a.subject ?? '').compareTo(b.subject ?? ''));
    } else if (type == TaskType.job) {
       if (_jobSort == 'date') tasks.sort((a, b) => a.date.compareTo(b.date));
       if (_jobSort == 'workplace') tasks.sort((a, b) => (a.workplace ?? '').compareTo(b.workplace ?? ''));
    } else {
      tasks.sort((a, b) => a.date.compareTo(b.date));
    }
    return tasks;
  }

  Widget _buildMonthView() {
    final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    final daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    final firstWeekday = firstDay.weekday;
    final totalCells = daysInMonth + (firstWeekday - 1);
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ["月","火","水","木","金","土","日"].map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))).toList()),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxHeight / rows;
              final cellWidth = constraints.maxWidth / 7;
              final ratio = cellWidth / cellHeight;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, 
                  childAspectRatio: ratio,
                ),
                itemCount: rows * 7,
                itemBuilder: (context, index) {
                  if (index < firstWeekday - 1 || index >= totalCells + (firstWeekday - 1)) return const SizedBox();
                  final day = index - (firstWeekday - 1) + 1;
                  if (day > daysInMonth) return const SizedBox();
                  final date = DateTime(_currentDate.year, _currentDate.month, day);
                  final isToday = isSameDay(date, DateTime.now());
                  final tasks = _allTasks.where((t) => isSameDay(t.date, date)).toList();

                  return GestureDetector(
                    onTap: () {
                       setState(() {
                         _currentDate = date;
                         _viewMode = CalendarViewMode.day;
                       });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isToday ? Colors.red.shade50 : Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Text("$day", style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.red : Colors.black, fontSize: 12)),
                          Expanded(
                            child: Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 2, runSpacing: 2,
                                children: tasks.take(6).map((t) => Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: _typeColors[t.type], shape: BoxShape.circle),
                                )).toList(),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskListView(List<Task> tasks) {
    if (tasks.isEmpty) return const Center(child: Text('予定はありません', style: TextStyle(color: Colors.grey)));
    
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        bool isYesterday = isSameDay(task.date, yesterday);

        String timeString;
        if (task.type == TaskType.assignment) {
           timeString = "${DateFormat('MM/dd(E)').format(task.date)} ${task.endTime.format(context)}";
        } else {
           String startStr = task.startTime.format(context);
           String endStr = task.endTime.format(context);
           timeString = "${DateFormat('MM/dd').format(task.date)} $startStr ~ $endStr";
        }

        return Card(
          elevation: 0,
          color: task.isCompleted ? Colors.grey.shade200 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: task.isCompleted ? Colors.grey : _typeColors[task.type]!.withValues(alpha: 0.3))),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            onTap: () => _showAddEditTaskDialog(task: task),
            leading: task.type == TaskType.assignment 
              ? Checkbox(
                  value: task.isCompleted, 
                  activeColor: Colors.grey,
                  onChanged: (v) {
                    setState(() { task.isCompleted = v ?? false; });
                    _saveData();
                  }
                )
              : CircleAvatar(backgroundColor: _typeColors[task.type], radius: 6),
            title: Row(children: [
              if(isYesterday) const Text("【昨日】 ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              Expanded(
                child: Text(
                  task.title, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? Colors.grey : Colors.black
                  )
                )
              ),
              if (task.hasLabel) const Icon(Icons.star, color: Colors.red, size: 18),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.type == TaskType.assignment) ...[
                  if (task.subject != null) Text("科目: ${task.subject}", style: const TextStyle(fontSize: 12)),
                  Text("提出: $timeString", style: TextStyle(fontWeight: FontWeight.bold, color: task.isCompleted ? Colors.grey : Colors.black87)),
                ] else ...[
                   Text(timeString),
                ],
                if (task.details != null && task.details!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(task.details!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildOverlapStack(List<Task> tasks, double width, {bool isSimple = false}) {
    if (tasks.isEmpty) return [];
    tasks.sort((a, b) => a.startTime.hour != b.startTime.hour 
         ? a.startTime.hour.compareTo(b.startTime.hour) 
         : a.startTime.minute.compareTo(b.startTime.minute));
    List<List<Task>> columns = [];
    for (var task in tasks) {
      bool placed = false;
      for (var col in columns) {
        var last = col.last;
        final lastEnd = last.endTime.hour * 60 + last.endTime.minute;
        final currentStart = task.startTime.hour * 60 + task.startTime.minute;
        if (currentStart >= lastEnd) { col.add(task); placed = true; break; }
      }
      if (!placed) columns.add([task]);
    }
    List<Widget> positionedTasks = [];
    int totalCols = columns.length;
    double colWidth = width / totalCols;
    for (int i = 0; i < totalCols; i++) {
      for (var task in columns[i]) {
        double top;
        double height;
        
        // ■■■ 修正：課題の表示位置計算（期限の30分前から終了まで） ■■■
        if (task.type == TaskType.assignment) {
           double endMinutes = task.endTime.hour * 60.0 + task.endTime.minute;
           top = endMinutes - 30.0; // 終了時間の30分前を開始位置にする
           height = 30.0;
        } else {
           top = task.startTime.hour * 60.0 + task.startTime.minute;
           height = (task.endTime.hour * 60 + task.endTime.minute) - top;
           if (height < 30) height = 30;
        }
        
        Color bgColor = task.isCompleted ? Colors.grey.shade300 : _typeBgColors[task.type]!;
        Color borderColor = task.isCompleted ? Colors.grey : _typeColors[task.type]!;

        Widget childContent;
        if (isSimple) {
           childContent = const SizedBox(); 
        } else {
           TextDecoration? decoration = task.isCompleted ? TextDecoration.lineThrough : null;
           childContent = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                task.title, 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: decoration), 
                overflow: TextOverflow.ellipsis
              ),
              if (task.type == TaskType.assignment) Text("期限: ${task.endTime.format(context)}", style: const TextStyle(fontSize: 8)),
           ]);
        }

        positionedTasks.add(Positioned(
          left: i * colWidth, top: top, width: colWidth - 1, height: height,
          child: GestureDetector(
            onTap: () => _showAddEditTaskDialog(task: task),
            child: Container(
              padding: isSimple ? EdgeInsets.zero : const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(left: BorderSide(color: borderColor, width: 3)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: childContent,
            ),
          ),
        ));
      }
    }
    return positionedTasks;
  }

  Widget _buildWeekView() {
    final startOfWeek = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    return Column(children: [
        Container(height: 40, color: Colors.grey.shade50, child: Row(children: [
            const SizedBox(width: 40),
            ...weekDays.map((date) => Expanded(child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: isSameDay(date, DateTime.now()) ? Colors.blue : Colors.transparent, borderRadius: BorderRadius.circular(4)), child: Text("${date.day}(${DateFormat('E', 'ja').format(date)})", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSameDay(date, DateTime.now()) ? Colors.white : Colors.black)))))
        ])),
        const Divider(height: 1),
        Expanded(child: SingleChildScrollView(child: SizedBox(height: 24 * 60.0, child: Stack(children: [
                  ...List.generate(24, (h) => Positioned(
                      top: h*60.0 - 7,
                      left:0, right:0, 
                      child: Row(children: [
                        SizedBox(width: 40, child: Text("$h:00", textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Colors.grey))), 
                        const Expanded(child: Divider(height: 1))
                      ])
                  )),
                  ...List.generate(7, (i) {
                     final date = weekDays[i];
                     final tasks = _allTasks.where((t) => isSameDay(t.date, date)).toList();
                     final colW = (MediaQuery.of(context).size.width - 40) / 7;
                     return Positioned(left: 40 + i * colW, top: 0, bottom: 0, width: colW, child: Stack(children: _buildOverlapStack(tasks, colW, isSimple: true)));
                  })
                ])))),
      ]);
  }

  Widget _buildDayView() {
    final tasks = _allTasks.where((t) => isSameDay(t.date, _currentDate)).toList();
    return SingleChildScrollView(child: SizedBox(height: 24 * 60.0, child: Stack(children: [
             ...List.generate(24, (h) => Positioned(
                 top: h * 60.0 - 7,
                 left: 0, right: 0, 
                 child: Row(children: [
                   SizedBox(width: 50, child: Text("$h:00", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.grey))), 
                   const Expanded(child: Divider(height: 1))
                 ])
             )),
             Positioned(left: 60, right: 10, top: 0, bottom: 0, child: Stack(children: _buildOverlapStack(tasks, MediaQuery.of(context).size.width - 70, isSimple: false)))
          ])));
  }

  Widget _buildTimetableView() {
    return Column(
      children: [
        Container(height: 30, color: Colors.blue.shade50, child: Row(children: [const SizedBox(width: 40), ...["月","火","水","木","金","土"].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))))] )),
        Expanded(
          child: Column(
            children: List.generate(5, (periodIndex) {
              final periodNum = periodIndex + 1;
              final timeSetting = _periodSettings[periodIndex];
              return Expanded(
                child: Row(
                  children: [
                    Container(width: 40, decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))), alignment: Alignment.center, 
                      child: Text("${timeSetting['name']}\n${timeSetting['start']}\n${timeSetting['end']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 8))),
                    ...List.generate(6, (dayIndex) {
                      final dayOfWeek = dayIndex + 1;
                      final cls = _timetable.firstWhere((c) => c.dayOfWeek == dayOfWeek && c.period == periodNum, orElse: () => ClassPeriod('', '', '', 0, 0));
                      final exists = cls.subject.isNotEmpty;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _showClassDetailDialog(dayOfWeek, periodNum, cls),
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(color: exists ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                            child: exists ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(cls.subject, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if(cls.absent > 0) Text("欠:${cls.absent}", style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                            ]) : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDateControlBar() {
    String label = "";
    VoidCallback onPrev = () {};
    VoidCallback onNext = () {};
    if (_viewMode == CalendarViewMode.month) {
      label = DateFormat('yyyy年 M月').format(_currentDate);
      onPrev = () => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1));
      onNext = () => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1));
    } else if (_viewMode == CalendarViewMode.week) {
      final startOfWeek = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
      label = "${DateFormat('M/d').format(startOfWeek)} の週";
      onPrev = () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 7)));
      onNext = () => setState(() => _currentDate = _currentDate.add(const Duration(days: 7)));
    } else {
      label = DateFormat('M月d日 (E)').format(_currentDate);
      onPrev = () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1)));
      onNext = () => setState(() => _currentDate = _currentDate.add(const Duration(days: 1)));
    }
    return Container(padding: const EdgeInsets.symmetric(vertical: 8), color: Colors.blue, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: onPrev), Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: onNext)]));
  }

  void _showTimeSettingDialog() {
    List<Map<String, TextEditingController>> controllers = _periodSettings.map((s) => {
      "start": TextEditingController(text: s['start']),
      "end": TextEditingController(text: s['end']),
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('時間割設定'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Text("${index + 1}限: "),
                  SizedBox(width: 60, child: TextField(
                    controller: controllers[index]['start'], 
                    textAlign: TextAlign.center, 
                    readOnly: true,
                    decoration: const InputDecoration(isDense: true),
                    onTap: () {
                      TimeOfDay current = TimeOfDay(
                         hour: int.parse(controllers[index]['start']!.text.split(':')[0]),
                         minute: int.parse(controllers[index]['start']!.text.split(':')[1])
                      );
                      _selectTime(context, current, (t) {
                         controllers[index]['start']!.text = "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";
                      }, minuteInterval: 5);
                    },
                  )),
                  const Text(" ~ "),
                  SizedBox(width: 60, child: TextField(
                    controller: controllers[index]['end'], 
                    textAlign: TextAlign.center, 
                    readOnly: true,
                    decoration: const InputDecoration(isDense: true),
                    onTap: () {
                       TimeOfDay current = TimeOfDay(
                         hour: int.parse(controllers[index]['end']!.text.split(':')[0]),
                         minute: int.parse(controllers[index]['end']!.text.split(':')[1])
                      );
                      _selectTime(context, current, (t) {
                         controllers[index]['end']!.text = "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";
                      }, minuteInterval: 5);
                    },
                  )),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                for (int i = 0; i < 5; i++) {
                  _periodSettings[i]['start'] = controllers[i]['start']!.text;
                  _periodSettings[i]['end'] = controllers[i]['end']!.text;
                }
              });
              await _saveData(); 
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showManageWorkplacesDialog() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(title: const Text('バイト先管理'), content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: _workplaces.length, itemBuilder: (c, i) => ListTile(title: Text(_workplaces[i]), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { 
          setDialogState(() => _workplaces.removeAt(i)); 
          await _saveData(); 
        })))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))]);
      }));
  }

  void _showClassDetailDialog(int day, int period, ClassPeriod current) {
    if (current.subject.isEmpty) return;
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: Text(current.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("教室: ${current.room} / 先生: ${current.teacher}"),
            const Divider(),
            const Text("出席管理", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildCounter(context, "出席", current.attended, Colors.blue, 
                () { setDialogState(() => current.attended++); _saveData(); },
                () { if(current.attended>0) setDialogState(() => current.attended--); _saveData(); }
              ),
              _buildCounter(context, "欠席", current.absent, Colors.red, 
                () { setDialogState(() => current.absent++); _saveData(); },
                () { if(current.absent>0) setDialogState(() => current.absent--); _saveData(); }
              ),
              _buildCounter(context, "遅刻", current.late, Colors.orange, 
                () { setDialogState(() => current.late++); _saveData(); },
                () { if(current.late>0) setDialogState(() => current.late--); _saveData(); }
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
        ],
      );
    }));
  }

  Widget _buildCounter(BuildContext context, String label, int count, Color color, VoidCallback onIncrement, VoidCallback onDecrement) {
    return Column(children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 5),
      Text("$count", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: color), 
            onPressed: onDecrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.add_circle, color: color), 
            onPressed: onIncrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      )
    ]);
  }

  void _showAddEditTaskDialog({Task? task}) {
    final isEdit = task != null;
    TaskType type = isEdit ? task.type : (_footerIndex == 2 ? TaskType.assignment : (_footerIndex == 3 ? TaskType.job : TaskType.private));
    
    String title = isEdit ? task.title : '';
    DateTime date = isEdit ? task.date : _currentDate;
    TimeOfDay start = isEdit ? task.startTime : const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay end = isEdit ? task.endTime : const TimeOfDay(hour: 13, minute: 0);
    String? subject = isEdit ? task.subject : null;
    String? workplace = isEdit ? task.workplace : null;
    bool hasLabel = isEdit ? task.hasLabel : false;
    String details = isEdit ? task.details ?? '' : '';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      
      void updateStart(TimeOfDay newStart) {
        setDialogState(() {
          start = newStart;
          int startMins = start.hour * 60 + start.minute;
          int endMins = end.hour * 60 + end.minute;
          if (endMins <= startMins) {
             end = TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
          }
        });
      }

      void updateEnd(TimeOfDay newEnd) {
        setDialogState(() {
          end = newEnd;
          int startMins = start.hour * 60 + start.minute;
          int endMins = end.hour * 60 + end.minute;
          if (endMins <= startMins) {
            start = TimeOfDay(hour: (end.hour - 1 + 24) % 24, minute: end.minute);
          }
        });
      }

      return AlertDialog(
        title: Text(isEdit ? '予定編集' : '予定追加'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<TaskType>(
              value: type, isExpanded: true,
              items: const [DropdownMenuItem(value: TaskType.assignment, child: Text('課題')), DropdownMenuItem(value: TaskType.job, child: Text('バイト')), DropdownMenuItem(value: TaskType.private, child: Text('私用'))],
              onChanged: (v) => setDialogState(() => type = v!),
            ),
            const Divider(),
            if(type == TaskType.assignment) ...[
              DropdownButton<String>(
                hint: const Text('科目選択 (時間割)'), value: _getSubjectsFromTimetable().contains(subject) ? subject : null, isExpanded: true,
                items: _getSubjectsFromTimetable().map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v)=>setDialogState((){ subject=v; title="$v課題"; }),
              ),
              TextField(decoration: const InputDecoration(labelText: 'タイトル'), controller: TextEditingController(text: title), onChanged: (v)=>title=v),
              SwitchListTile(title: const Text('重要ラベル'), value: hasLabel, onChanged: (v)=>setDialogState(()=>hasLabel=v)),
              ListTile(
                title: Text("提出期限: ${DateFormat('yyyy/MM/dd(E) HH:mm').format(DateTime(date.year, date.month, date.day, end.hour, end.minute))}"), 
                leading: const Icon(Icons.timer_off), 
                subtitle: const Text("タップして日時を変更", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              Row(
                children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       icon: const Icon(Icons.calendar_month),
                       label: Text(DateFormat('M/d').format(date)),
                       onPressed: () async {
                         final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2025), lastDate: DateTime(2030), locale: const Locale('ja'));
                         if(d!=null) setDialogState((){ date=d; });
                       },
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: OutlinedButton.icon(
                       icon: const Icon(Icons.access_time),
                       label: Text(end.format(context)),
                       onPressed: () {
                         _selectTime(context, end, (t) {
                            setDialogState((){ 
                              end=t; 
                              // ■■■ 修正：期限の30分前を開始時間にする（自動設定） ■■■
                              final now = DateTime.now();
                              final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                              final st = dt.subtract(const Duration(minutes: 30));
                              start = TimeOfDay(hour: st.hour, minute: st.minute);
                            });
                         });
                       },
                     ),
                   ),
                ],
              )
            ],
            if(type == TaskType.job || type == TaskType.private) ...[
               if(type == TaskType.job) ...[
                 DropdownButton<String>(
                  hint: const Text('バイト先選択'), value: _workplaces.contains(workplace) ? workplace : null, isExpanded: true,
                  items: [..._workplaces.map((w)=>DropdownMenuItem(value: w, child: Text(w))), const DropdownMenuItem(value: 'NEW', child: Text('+ 新規追加'))],
                  onChanged: (v) {
                    if(v=='NEW') { setDialogState((){ workplace=''; title=''; }); } else { setDialogState((){ workplace=v; title=v!; }); }
                  },
                ),
                if(workplace=='') TextField(decoration: const InputDecoration(labelText: '新しいバイト先'), onChanged: (v){ workplace=v; title=v; }),
               ],
               if(type == TaskType.private) TextField(decoration: const InputDecoration(labelText: 'タイトル'), controller: TextEditingController(text: title), onChanged: (v)=>title=v),
               
               const SizedBox(height: 10),
               _buildDateTimeSeparatedRow(context, date, start, end, 
                (d) => setDialogState(() => date=d), 
                updateStart, 
                updateEnd
              ),
            ],
            TextField(decoration: const InputDecoration(labelText: '内容(詳細)'), controller: TextEditingController(text: details), onChanged: (v)=>details=v),
          ]),
        ),
        actions: [
          if(isEdit) TextButton(onPressed: () async { 
            setState(()=>_allTasks.removeWhere((t)=>t.id==task.id)); 
            await _saveData();
            if (!mounted) return;
            Navigator.pop(context); 
          }, child: const Text('削除', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () async {
            if(title.isEmpty) return;
            if(type == TaskType.job && (workplace == null || workplace!.isEmpty)) return;
            final overlaps = _checkOverlap(date, start, end, type, excludeId: isEdit ? task.id : null);
            if(overlaps.isNotEmpty) {
               showDialog(context: context, builder: (ctx) => AlertDialog(
                 title: const Text('⚠️ 予定が被っています'),
                 content: Text("${overlaps.map((t)=>t.title).join(', ')} と重なっています。\n登録しますか？"),
                 actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('やめる')), TextButton(onPressed: () async { 
                   Navigator.pop(ctx); 
                   await _saveTask(isEdit, task?.id, title, date, start, end, type, subject, hasLabel, workplace, details, task?.isCompleted); 
                   if (!mounted) return;
                   Navigator.pop(context); 
                 }, child: const Text('登録する', style: TextStyle(color: Colors.red)))]
               ));
            } else {
               await _saveTask(isEdit, task?.id, title, date, start, end, type, subject, hasLabel, workplace, details, task?.isCompleted);
               if (!mounted) return;
               Navigator.pop(context);
            }
          }, child: const Text('保存')),
        ],
      );
    }));
  }

  Widget _buildDateTimeSeparatedRow(BuildContext context, DateTime d, TimeOfDay s, TimeOfDay e, Function(DateTime) onDateChange, Function(TimeOfDay) onStartChange, Function(TimeOfDay) onEndChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("日時設定:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('yyyy/MM/dd(E)').format(d), style: const TextStyle(fontSize: 12)),
                onPressed: () async {
                   final pd = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2025), lastDate: DateTime(2030), locale: const Locale('ja'));
                   if(pd!=null) onDateChange(pd);
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                child: Text("開始 ${s.format(context)}"),
                onPressed: () => _selectTime(context, s, onStartChange),
              ),
            ),
            const SizedBox(width: 5),
            const Text("-"),
            const SizedBox(width: 5),
            Expanded(
              child: OutlinedButton(
                child: Text("終了 ${e.format(context)}"),
                onPressed: () => _selectTime(context, e, onEndChange),
              ),
            ),
          ],
        )
      ]
    );
  }

  Future<void> _saveTask(bool isEdit, String? id, String title, DateTime date, TimeOfDay start, TimeOfDay end, TaskType type, String? subject, bool hasLabel, String? workplace, String details, bool? isCompleted) async {
    if(type == TaskType.job && workplace != null && !_workplaces.contains(workplace)) {
      _workplaces.add(workplace);
    }
    setState(() {
      if(isEdit) _allTasks.removeWhere((t)=>t.id==id);
      _allTasks.add(Task(
        id: id ?? DateTime.now().toString(),
        title: title, date: date, startTime: start, endTime: end, type: type,
        color: _typeColors[type]!,
        subject: subject, hasLabel: hasLabel, workplace: workplace, details: details,
        isCompleted: isCompleted ?? false,
      ));
    });
    await _saveData();
  }
}

// ■■■ 時間割編集専用ページ ■■■
class TimetableEditorPage extends StatefulWidget {
  final List<ClassPeriod> timetable;
  final List<Map<String, String>> periodSettings;
  final Function(List<ClassPeriod>) onSave;

  const TimetableEditorPage({
    super.key,
    required this.timetable,
    required this.periodSettings,
    required this.onSave,
  });

  @override
  State<TimetableEditorPage> createState() => _TimetableEditorPageState();
}

class _TimetableEditorPageState extends State<TimetableEditorPage> {
  late List<ClassPeriod> _localTimetable;

  @override
  void initState() {
    super.initState();
    _localTimetable = List.from(widget.timetable);
  }

  void _showEditTimetableDialog(int day, int period) {
    ClassPeriod current = _localTimetable.firstWhere(
      (c) => c.dayOfWeek == day && c.period == period,
      orElse: () => ClassPeriod('', '', '', day, period),
    );

    String s = current.subject, r = current.room, t = current.teacher;
    
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('授業編集'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(decoration: const InputDecoration(labelText: '科目'), controller: TextEditingController(text: s), onChanged: (v)=>s=v), TextField(decoration: const InputDecoration(labelText: '教室'), controller: TextEditingController(text: r), onChanged: (v)=>r=v), TextField(decoration: const InputDecoration(labelText: '先生'), controller: TextEditingController(text: t), onChanged: (v)=>t=v)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')), ElevatedButton(onPressed: () { 
      setState(() { 
        _localTimetable.removeWhere((c)=>c.dayOfWeek==day && c.period==period); 
        if (s.isNotEmpty || r.isNotEmpty || t.isNotEmpty) {
           _localTimetable.add(ClassPeriod(s, r, t, day, period, attended: current.attended, absent: current.absent, late: current.late)); 
        }
      });
      widget.onSave(_localTimetable);
      Navigator.pop(context); 
    }, child: const Text('保存'))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('時間割の登録・修正'), backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Column(
        children: [
          Container(height: 30, color: Colors.blue.shade50, child: Row(children: [const SizedBox(width: 40), ...["月","火","水","木","金","土"].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))))] )),
          Expanded(
            child: Column(
              children: List.generate(5, (periodIndex) {
                final periodNum = periodIndex + 1;
                final timeSetting = widget.periodSettings[periodIndex];
                return Expanded(
                  child: Row(
                    children: [
                      Container(width: 40, decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))), alignment: Alignment.center, 
                        child: Text("${timeSetting['name']}\n${timeSetting['start']}\n${timeSetting['end']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 8))),
                      ...List.generate(6, (dayIndex) {
                        final dayOfWeek = dayIndex + 1;
                        final cls = _localTimetable.firstWhere((c) => c.dayOfWeek == dayOfWeek && c.period == periodNum, orElse: () => ClassPeriod('', '', '', 0, 0));
                        final exists = cls.subject.isNotEmpty;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _showEditTimetableDialog(dayOfWeek, periodNum),
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(color: exists ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                              child: exists ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(cls.subject, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text(cls.room, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.black54)),
                              ]) : const Center(child: Icon(Icons.add, size: 12, color: Colors.grey)), 
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}