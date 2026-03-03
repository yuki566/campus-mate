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

class Workplace {
  String name;
  int mealCost;

  Workplace(this.name, {this.mealCost = 0});

  Map<String, dynamic> toJson() => {'name': name, 'mealCost': mealCost};
  factory Workplace.fromJson(Map<String, dynamic> json) => 
      Workplace(json['name'], mealCost: json['mealCost'] ?? 0);
}

class Task {
  String id;
  String title;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  bool isAllDay;
  TaskType type;
  Color color;
  String? subject;
  bool hasLabel;
  String? workplace;
  String? details;
  bool isCompleted;
  
  int? salary;
  double? workHours;
  bool hasMeal;

  Task({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.color,
    this.isAllDay = false,
    this.subject,
    this.hasLabel = false,
    this.workplace,
    this.details,
    this.isCompleted = false,
    this.salary,
    this.workHours,
    this.hasMeal = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
    'isAllDay': isAllDay,
    'type': type.index,
    'color': color.value,
    'subject': subject,
    'hasLabel': hasLabel,
    'workplace': workplace,
    'details': details,
    'isCompleted': isCompleted,
    'salary': salary,
    'workHours': workHours,
    'hasMeal': hasMeal,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      startTime: TimeOfDay(hour: json['startHour'], minute: json['startMinute']),
      endTime: TimeOfDay(hour: json['endHour'], minute: json['endMinute']),
      isAllDay: json['isAllDay'] ?? false,
      type: TaskType.values[json['type']],
      color: Color(json['color']),
      subject: json['subject'],
      hasLabel: json['hasLabel'] ?? false,
      workplace: json['workplace'],
      details: json['details'],
      isCompleted: json['isCompleted'] ?? false,
      salary: json['salary'],
      workHours: json['workHours'],
      hasMeal: json['hasMeal'] ?? false,
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  DateTime _currentDate = DateTime.now();
  int _footerIndex = 0; 
  CalendarViewMode _viewMode = CalendarViewMode.month;

  // ソート・フィルタ状態
  String _assignmentSort = 'deadline'; 
  String _jobSort = 'date'; 
  bool _filterImportantOnly = false;
  bool _filterUnenteredSalary = false;
  bool _filterIncompleteAssignment = false; // 課題:未完了のみ

  List<Task> _allTasks = [];
  List<ClassPeriod> _timetable = [];
  List<Workplace> _workplaces = [Workplace('セブンイレブン'), Workplace('スタバ')]; 

  // タブコントローラー（バイト画面用）
  late TabController _jobTabController;
  int _currentJobTabIndex = 0;

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
    _jobTabController = TabController(length: 3, vsync: this);
    _jobTabController.addListener(() {
      setState(() {
        _currentJobTabIndex = _jobTabController.index;
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _jobTabController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = _allTasks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('tasks', tasksJson);
      final timetableJson = _timetable.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('timetable', timetableJson);
      
      final workplacesJson = _workplaces.map((w) => jsonEncode(w.toJson())).toList();
      await prefs.setStringList('workplaces_v2', workplacesJson);

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
        final wpList = prefs.getStringList('workplaces_v2');
        if (wpList != null) {
          _workplaces = wpList.map((w) => Workplace.fromJson(jsonDecode(w))).toList();
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
      _workplaces = [Workplace('セブンイレブン'), Workplace('スタバ')];
    });
    _saveData(); 
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  
  List<String> _getSubjectsFromTimetable() {
    final list = _timetable.map((e) => e.subject).toSet().toList();
    list.add("その他");
    return list;
  }

  List<Task> _checkOverlap(DateTime date, TimeOfDay start, TimeOfDay end, TaskType type, bool isAllDay, {String? excludeId}) {
    if(isAllDay) return [];
    
    final newStartMins = start.hour * 60 + start.minute;
    final newEndMins = end.hour * 60 + end.minute;

    return _allTasks.where((t) {
      if (t.id == excludeId) return false;
      if (!isSameDay(t.date, date)) return false;
      if (t.isCompleted) return false;
      if (t.isAllDay) return false;
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
      // 修正: バイト画面用FAB (黄色)
      floatingActionButton: _getFloatingActionButton(),
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

  Widget? _getFloatingActionButton() {
    if (_footerIndex == 1) return null; // 時間割
    if (_footerIndex == 3) {
      // バイト画面: 黄色の四角いボタン
      return FloatingActionButton(
        onPressed: () => _showAddEditTaskDialog(),
        backgroundColor: Colors.amber, // 色変更
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 四角（角丸）
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    // 月カレンダーとその他
    if (_footerIndex == 0 && _viewMode == CalendarViewMode.month) return null;
    
    // 通常の丸いボタン
    return FloatingActionButton(
      onPressed: () => _showAddEditTaskDialog(),
      backgroundColor: _getCurrentHeaderColor(),
      child: const Icon(Icons.add, color: Colors.white),
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
            title: const Text('時間割・時間設定'),
            subtitle: const Text('科目の登録や時間の変更を一括管理'),
            onTap: () { 
              Navigator.pop(context); 
              _navigateToTimetableEditor(); 
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('バイト先管理'),
            subtitle: const Text('名称やまかない代の設定'),
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
      content: const Text('この操作は取り消せません。\n登録したすべての予定、時間割、設定が削除されます。'),
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
    
    // バイト画面の場合はAppBarを返さない（Body側で構築）
    if (_footerIndex == 3) {
      return AppBar(toolbarHeight: 0, backgroundColor: Colors.amber);
    }

    if (_footerIndex > 1) {
      String title = _footerIndex == 2 ? '課題一覧' : '私用';
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
    if (_footerIndex == 2) {
      return Row(
        children: [
          IconButton(
            icon: Icon(_filterImportantOnly ? Icons.label : Icons.label_outline, color: color),
            tooltip: '重要のみ表示',
            onPressed: () => setState(() => _filterImportantOnly = !_filterImportantOnly),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: color), 
            onSelected: (val) {
               setState(() => _assignmentSort = val);
            },
            itemBuilder: (context) {
               return const [PopupMenuItem(value: 'deadline', child: Text('提出日順')), PopupMenuItem(value: 'subject', child: Text('科目順'))];
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
        height: 250, color: Colors.white,
        child: Column(children: [
          SizedBox(height: 180, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: initialDateTime, use24hFormat: true, minuteInterval: minuteInterval, onDateTimeChanged: (val) => onSelected(TimeOfDay(hour: val.hour, minute: val.minute)))),
          CupertinoButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop())
        ]),
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
        height: 250, color: Colors.white,
        child: Column(children: [
          SizedBox(height: 180, child: CupertinoPicker(itemExtent: 32, scrollController: FixedExtentScrollController(initialItem: selectedIndex), onSelectedItemChanged: (i) => selectedIndex = i, children: items.map((m) => Center(child: Text("$m 分前"))).toList())),
          CupertinoButton(child: const Text('決定'), onPressed: () { onSelected(items[selectedIndex]); Navigator.of(context).pop(); })
        ]),
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
      builder: (context) => TimetableCombinedPage(
        periodSettings: _periodSettings,
        timetable: _timetable,
        onSave: (newTimetable, newSettings) {
          setState(() { 
            _timetable = newTimetable; 
            _periodSettings = newSettings;
          });
          _saveData();
        },
      ),
    ));
  }

  Widget _buildBody() {
    if (_footerIndex == 1) return _buildTimetableView();
    if (_footerIndex == 3) return _buildJobDashboard(); 
    if (_footerIndex > 1) {
      TaskType type = _footerIndex == 2 ? TaskType.assignment : TaskType.private;
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

  Widget _buildJobDashboard() {
    // Scaffoldをネストせず、Column等で構成（状態管理のため）
    return Scaffold(
      appBar: AppBar(
        title: const Text("バイト管理", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.amber,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _jobTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "シフト"),
            Tab(text: "給料"),
            Tab(text: "分析"),
          ],
        ),
        actions: [
          // 分析タブのときは非表示
          if (_currentJobTabIndex != 2)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.white), 
              onSelected: (val) {
                 setState(() => _jobSort = val);
              },
              itemBuilder: (context) {
                 return const [PopupMenuItem(value: 'date', child: Text('日付順')), PopupMenuItem(value: 'workplace', child: Text('バイト先別'))];
              },
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: TabBarView(
        controller: _jobTabController,
        children: [
          _buildJobShiftList(),
          _buildJobSalaryList(),
          _buildJobAnalysis(),
        ],
      ),
    );
  }

  Widget _buildJobShiftList() {
    List<Task> tasks = _getFilteredAndSortedTasks(TaskType.job);
    DateTime now = DateTime.now();
    DateTime yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    tasks = tasks.where((t) => t.date.isAfter(yesterday)).toList();
    
    if (_jobSort == 'workplace') {
      tasks.sort((a, b) {
        int cmp = (a.workplace ?? '').compareTo(b.workplace ?? '');
        return cmp != 0 ? cmp : a.date.compareTo(b.date);
      });
    } else {
      tasks.sort((a,b)=>a.date.compareTo(b.date));
    }

    if(tasks.isEmpty) return const Center(child: Text("これからのシフトはありません"));

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.amber.shade200)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.amber, radius: 6),
            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${DateFormat('yyyy/MM/dd(E)', 'ja').format(task.date)} ${task.startTime.format(context)}~${task.endTime.format(context)}"),
            onTap: () => _showAddEditTaskDialog(task: task),
          ),
        );
      },
    );
  }

  Widget _buildJobSalaryList() {
    List<Task> tasks = _allTasks.where((t) => t.type == TaskType.job).toList();
    
    if (_jobSort == 'workplace') {
      tasks.sort((a, b) {
        int cmp = (a.workplace ?? '').compareTo(b.workplace ?? '');
        return cmp != 0 ? cmp : b.date.compareTo(a.date);
      });
    } else {
      tasks.sort((a,b)=>b.date.compareTo(a.date));
    }

    if (_filterUnenteredSalary) {
      tasks = tasks.where((t) => t.salary == null).toList();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilterChip(
                label: const Text("未入力のみ表示"),
                selected: _filterUnenteredSalary,
                onSelected: (v) => setState(() => _filterUnenteredSalary = v),
                selectedColor: Colors.orange.shade100,
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty 
            ? const Center(child: Text("表示するデータがありません"))
            : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                bool isEntered = task.salary != null;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: isEntered ? Colors.white : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isEntered ? Colors.green.shade200 : Colors.grey.shade300)),
                  child: ListTile(
                    leading: Icon(isEntered ? Icons.check_circle : Icons.circle_outlined, color: isEntered ? Colors.green : Colors.grey),
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('yyyy/MM/dd(E)', 'ja').format(task.date)),
                    trailing: isEntered 
                      ? Text("¥${NumberFormat('#,###').format(task.salary)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))
                      : const Text("未入力", style: TextStyle(color: Colors.red)),
                    onTap: () {
                       int? s = task.salary;
                       double? h = task.workHours;
                       bool m = task.hasMeal;
                       showDialog(context: context, builder: (ctx) => AlertDialog(
                         title: Text("${task.title} 実績入力"),
                         content: Column(mainAxisSize: MainAxisSize.min, children: [
                           TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "給料 (円)", suffixText: "円"), controller: TextEditingController(text: s?.toString()), onChanged: (v)=>s=int.tryParse(v)),
                           TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "勤務時間 (h)", suffixText: "時間"), controller: TextEditingController(text: h?.toString()), onChanged: (v)=>h=double.tryParse(v)),
                           StatefulBuilder(builder: (c, ss) => CheckboxListTile(title: const Text("まかない利用"), value: m, onChanged: (v)=>ss(()=>m=v!))),
                         ]),
                         actions: [
                           TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("キャンセル")),
                           ElevatedButton(onPressed: () {
                              setState(() {
                                task.salary = s;
                                task.workHours = h;
                                task.hasMeal = m;
                              });
                              _saveData();
                              Navigator.pop(ctx);
                           }, child: const Text("保存")),
                         ],
                       ));
                    },
                  ),
                );
              },
            ),
        ),
      ],
    );
  }

  Widget _buildJobAnalysis() {
    return _JobAnalysisView(tasks: _allTasks.where((t)=>t.type==TaskType.job).toList(), workplaces: _workplaces);
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
    
    // 修正: 課題の未完了フィルタ
    if (_filterIncompleteAssignment && type == TaskType.assignment) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }

    if (type == TaskType.assignment) {
      if (_assignmentSort == 'deadline') tasks.sort((a, b) => a.date.compareTo(b.date));
      if (_assignmentSort == 'subject') tasks.sort((a, b) => (a.subject ?? '').compareTo(b.subject ?? ''));
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

    return Column(
      children: [
        // 修正: 課題タブの場合のみ未完了フィルタを表示
        if (_footerIndex == 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilterChip(
                  label: const Text("未完了のみ表示"),
                  selected: _filterIncompleteAssignment,
                  onSelected: (v) => setState(() => _filterIncompleteAssignment = v),
                  selectedColor: Colors.blue.shade100,
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              bool isYesterday = isSameDay(task.date, yesterday);

              String timeString;
              if (task.isAllDay) {
                timeString = "${DateFormat('MM/dd').format(task.date)} 終日";
              } else if (task.type == TaskType.assignment) {
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
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOverlapStack(List<Task> tasks, double width) {
    final timeTasks = tasks.where((t) => !t.isAllDay).toList();
    if (timeTasks.isEmpty) return [];

    timeTasks.sort((a, b) => a.startTime.hour != b.startTime.hour 
         ? a.startTime.hour.compareTo(b.startTime.hour) 
         : a.startTime.minute.compareTo(b.startTime.minute));
    List<List<Task>> columns = [];
    for (var task in timeTasks) {
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
        
        if (task.type == TaskType.assignment) {
           double endMinutes = task.endTime.hour * 60.0 + task.endTime.minute;
           top = endMinutes - 30.0;
           height = 30.0;
        } else {
           top = task.startTime.hour * 60.0 + task.startTime.minute;
           height = (task.endTime.hour * 60 + task.endTime.minute) - top;
           if (height < 30) height = 30;
        }
        
        Color bgColor = task.isCompleted ? Colors.grey.shade300 : _typeBgColors[task.type]!;
        Color borderColor = task.isCompleted ? Colors.grey : _typeColors[task.type]!;

        TextDecoration? decoration = task.isCompleted ? TextDecoration.lineThrough : null;
        
        Widget childContent = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            task.title, 
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, decoration: decoration), 
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            task.type == TaskType.assignment 
             ? "期限:${task.endTime.format(context)}"
             : "${task.startTime.format(context)}~",
            style: const TextStyle(fontSize: 8),
            overflow: TextOverflow.ellipsis
          ),
        ]);

        positionedTasks.add(Positioned(
          left: i * colWidth, top: top, width: colWidth - 1, height: height,
          child: GestureDetector(
            onTap: () => _showAddEditTaskDialog(task: task),
            child: Container(
              padding: const EdgeInsets.all(2),
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

  Widget _buildAllDayArea(List<Task> tasks) {
    final allDayTasks = tasks.where((t) => t.isAllDay).toList();
    if (allDayTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      children: allDayTasks.map((t) => GestureDetector(
        onTap: () => _showAddEditTaskDialog(task: t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          width: double.infinity,
          decoration: BoxDecoration(color: _typeColors[t.type], borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                 margin: const EdgeInsets.only(right: 5),
                 decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                 child: const Text("終日", style: TextStyle(color: Colors.white, fontSize: 9)),
               ),
               Expanded(child: Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      )).toList(),
    );
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
        Container(
          constraints: const BoxConstraints(minHeight: 0, maxHeight: 100), 
          child: SingleChildScrollView(
            child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const SizedBox(width: 40),
                 ...weekDays.map((date) {
                   final tasks = _allTasks.where((t) => isSameDay(t.date, date)).toList();
                   return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _buildAllDayArea(tasks)));
                 })
            ]),
          ),
        ),
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
                     return Positioned(left: 40 + i * colW, top: 0, bottom: 0, width: colW, child: Stack(children: _buildOverlapStack(tasks, colW)));
                  })
                ])))),
      ]);
  }

  Widget _buildDayView() {
    final tasks = _allTasks.where((t) => isSameDay(t.date, _currentDate)).toList();
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(4), child: _buildAllDayArea(tasks)), 
        Expanded(
          child: SingleChildScrollView(child: SizedBox(height: 24 * 60.0, child: Stack(children: [
                   ...List.generate(24, (h) => Positioned(
                       top: h * 60.0 - 7,
                       left: 0, right: 0, 
                       child: Row(children: [
                         SizedBox(width: 50, child: Text("$h:00", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.grey))), 
                         const Expanded(child: Divider(height: 1))
                       ])
                   )),
                   Positioned(left: 60, right: 10, top: 0, bottom: 0, child: Stack(children: _buildOverlapStack(tasks, MediaQuery.of(context).size.width - 70)))
                ]))),
        ),
      ],
    );
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
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: exists ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                            child: exists ? Column(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Text(cls.subject, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), softWrap: true),
                                if(cls.room.isNotEmpty) Text(cls.room, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8)),
                                if(cls.teacher.isNotEmpty) Text(cls.teacher, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8)),
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

  void _showManageWorkplacesDialog() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(title: const Text('バイト先管理'), content: SizedBox(width: double.maxFinite, child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add), label: const Text("バイト先を追加"),
              onPressed: () async {
                String newName = "";
                int newCost = 0;
                await showDialog(context: context, builder: (c)=>AlertDialog(
                  title: const Text("追加"), 
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(decoration: const InputDecoration(labelText: "名称"), onChanged: (v)=>newName=v),
                    TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "まかない代 (円)"), onChanged: (v)=>newCost=int.tryParse(v)??0),
                  ]),
                  actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("OK"))]
                ));
                if(newName.isNotEmpty) { 
                  setDialogState(()=>_workplaces.add(Workplace(newName, mealCost: newCost))); 
                  _saveData(); 
                }
              },
            ),
            Expanded(
              child: ListView.builder(shrinkWrap: true, itemCount: _workplaces.length, itemBuilder: (c, i) {
                final wp = _workplaces[i];
                return ListTile(
                  title: Text(wp.name), 
                  subtitle: Text("まかない: ¥${wp.mealCost}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () async {
                         int newCost = wp.mealCost;
                         await showDialog(context: context, builder: (subCtx)=>AlertDialog(
                           title: Text("${wp.name} 設定"),
                           content: Column(mainAxisSize: MainAxisSize.min, children: [
                             const Text("まかない代 (円)"),
                             TextField(keyboardType: TextInputType.number, controller: TextEditingController(text: wp.mealCost.toString()), onChanged: (v)=>newCost=int.tryParse(v)??0)
                           ]),
                           actions: [TextButton(onPressed: ()=>Navigator.pop(subCtx), child: const Text("OK"))],
                         ));
                         setDialogState(()=>wp.mealCost = newCost);
                         _saveData();
                      }),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                         setDialogState(() => _workplaces.removeAt(i)); 
                         await _saveData(); 
                      }),
                    ],
                  ),
                );
              }),
            ),
          ],
        )), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))]);
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
          IconButton(icon: Icon(Icons.remove_circle_outline, color: color), onPressed: onDecrement, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 10),
          IconButton(icon: Icon(Icons.add_circle, color: color), onPressed: onIncrement, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
    bool isAllDay = isEdit ? task.isAllDay : false;
    String? subject = isEdit ? task.subject : null;
    String? workplace = isEdit ? task.workplace : null;
    bool hasLabel = isEdit ? task.hasLabel : false;
    String details = isEdit ? task.details ?? '' : '';
    
    int? inputSalary = isEdit ? task.salary : null;
    double? inputWorkHours = isEdit ? task.workHours : null;
    bool inputHasMeal = isEdit ? task.hasMeal : false;

    int jobTabIndex = 0; 

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

      Widget buildTimeInput() {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                child: Text("開始 ${start.format(context)}"),
                onPressed: () => _selectTime(context, start, updateStart),
              ),
            ),
            const SizedBox(width: 5),
            const Text("-"),
            const SizedBox(width: 5),
            Expanded(
              child: OutlinedButton(
                child: Text("終了 ${end.format(context)}"),
                onPressed: () => _selectTime(context, end, updateEnd),
              ),
            ),
          ],
        );
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

            if (type == TaskType.job)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CupertinoSegmentedControl<int>(
                  children: const {0: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("シフト(予定)")), 1: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("給与(実績)"))},
                  groupValue: jobTabIndex,
                  onValueChanged: (v) => setDialogState(() => jobTabIndex = v),
                ),
              ),

            if(type == TaskType.assignment) ...[
              DropdownButton<String>(
                hint: const Text('科目選択 (時間割)'), value: _getSubjectsFromTimetable().contains(subject) ? subject : null, isExpanded: true,
                items: _getSubjectsFromTimetable().map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v)=>setDialogState((){ subject=v; title="$v課題"; }),
              ),
              TextField(decoration: const InputDecoration(labelText: 'タイトル'), controller: TextEditingController(text: title), onChanged: (v)=>title=v),
              SwitchListTile(title: const Text('重要ラベル'), value: hasLabel, onChanged: (v)=>setDialogState(()=>hasLabel=v)),
            ],

            if(type == TaskType.job && jobTabIndex == 0) ...[
              DropdownButton<String>(
                hint: const Text('バイト先選択'), value: _workplaces.any((w)=>w.name==workplace) ? workplace : null, isExpanded: true,
                items: [..._workplaces.map((w)=>DropdownMenuItem(value: w.name, child: Text(w.name))), const DropdownMenuItem(value: 'NEW', child: Text('+ 新規追加'))],
                onChanged: (v) {
                  if(v=='NEW') { setDialogState((){ workplace=''; title=''; }); } else { setDialogState((){ workplace=v; title=v!; }); }
                },
              ),
              if(workplace=='') TextField(decoration: const InputDecoration(labelText: '新しいバイト先'), onChanged: (v){ workplace=v; title=v; }),
            ],

            if(type == TaskType.job && jobTabIndex == 1) ...[
              const Align(alignment: Alignment.centerLeft, child: Text("実績入力", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              Row(children: [
                  Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '給料(円)'), controller: TextEditingController(text: inputSalary?.toString()), onChanged: (v)=>inputSalary=int.tryParse(v))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '時間(h)'), controller: TextEditingController(text: inputWorkHours?.toString()), onChanged: (v)=>inputWorkHours=double.tryParse(v))),
                ]),
                CheckboxListTile(
                  title: const Text("まかない食べた？"), 
                  value: inputHasMeal, 
                  onChanged: (v) => setDialogState((){ inputHasMeal = v!; }),
                ),
            ],

            if(type == TaskType.private) ...[
               TextField(decoration: const InputDecoration(labelText: 'タイトル'), controller: TextEditingController(text: title), onChanged: (v)=>title=v),
               SwitchListTile(title: const Text("終日"), value: isAllDay, onChanged: (v)=>setDialogState(()=>isAllDay=v)),
            ],
            
            if (!(type == TaskType.job && jobTabIndex == 1)) ...[
              if(!isAllDay) ...[
                if(type == TaskType.assignment)
                  ListTile(
                    title: Text("提出期限: ${DateFormat('yyyy/MM/dd(E) HH:mm').format(DateTime(date.year, date.month, date.day, end.hour, end.minute))}"), 
                    leading: const Icon(Icons.timer_off), 
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
                                if(type == TaskType.assignment){
                                  final now = DateTime.now();
                                  final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                                  final st = dt.subtract(const Duration(minutes: 30));
                                  start = TimeOfDay(hour: st.hour, minute: st.minute);
                                } else {
                                  start = TimeOfDay(hour: t.hour-1, minute: t.minute);
                                }
                              });
                           });
                         },
                       ),
                     ),
                  ],
                ),
                if(type != TaskType.assignment) buildTimeInput(),
              ],
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
            
            final overlaps = _checkOverlap(date, start, end, type, isAllDay, excludeId: isEdit ? task.id : null);
            if(overlaps.isNotEmpty) {
               showDialog(context: context, builder: (ctx) => AlertDialog(
                 title: const Text('⚠️ 予定が被っています'),
                 content: Text("${overlaps.map((t)=>t.title).join(', ')} と重なっています。\n登録しますか？"),
                 actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('やめる')), TextButton(onPressed: () async { 
                   Navigator.pop(ctx); 
                   await _saveTask(isEdit, task?.id, title, date, start, end, type, subject, hasLabel, workplace, details, task?.isCompleted, isAllDay, inputSalary, inputWorkHours, inputHasMeal); 
                   if (!mounted) return;
                   Navigator.pop(context); 
                 }, child: const Text('登録する', style: TextStyle(color: Colors.red)))]
               ));
            } else {
               await _saveTask(isEdit, task?.id, title, date, start, end, type, subject, hasLabel, workplace, details, task?.isCompleted, isAllDay, inputSalary, inputWorkHours, inputHasMeal);
               if (!mounted) return;
               Navigator.pop(context);
            }
          }, child: const Text('保存')),
        ],
      );
    }));
  }

  Future<void> _saveTask(bool isEdit, String? id, String title, DateTime date, TimeOfDay start, TimeOfDay end, TaskType type, String? subject, bool hasLabel, String? workplace, String details, bool? isCompleted, bool isAllDay, int? salary, double? workHours, bool hasMeal) async {
    if(type == TaskType.job && workplace != null && !_workplaces.any((w)=>w.name==workplace)) {
      _workplaces.add(Workplace(workplace));
    }
    setState(() {
      if(isEdit) _allTasks.removeWhere((t)=>t.id==id);
      _allTasks.add(Task(
        id: id ?? DateTime.now().toString(),
        title: title, date: date, startTime: start, endTime: end, type: type,
        color: _typeColors[type]!,
        subject: subject, hasLabel: hasLabel, workplace: workplace, details: details,
        isCompleted: isCompleted ?? false,
        isAllDay: isAllDay,
        salary: salary,
        workHours: workHours,
        hasMeal: hasMeal,
      ));
    });
    await _saveData();
  }
}

class _JobAnalysisView extends StatefulWidget {
  final List<Task> tasks;
  final List<Workplace> workplaces;
  const _JobAnalysisView({required this.tasks, required this.workplaces});
  @override
  State<_JobAnalysisView> createState() => _JobAnalysisViewState();
}

class _JobAnalysisViewState extends State<_JobAnalysisView> {
  int _periodMode = 1; 
  DateTime _targetDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    DateTime start, end;
    String label;
    if(_periodMode == 0) {
      start = DateTime(_targetDate.year, _targetDate.month, _targetDate.day);
      end = start.add(const Duration(days: 1));
      label = DateFormat("yyyy/MM/dd").format(start);
    } else if(_periodMode == 1) { 
      start = DateTime(_targetDate.year, _targetDate.month, 1);
      end = DateTime(_targetDate.year, _targetDate.month + 1, 1);
      label = DateFormat("yyyy年M月").format(start);
    } else { 
      start = DateTime(_targetDate.year, 1, 1);
      end = DateTime(_targetDate.year + 1, 1, 1);
      label = "${start.year}年";
    }

    List<Task> targetTasks = widget.tasks.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(end)).toList();
    
    int totalIncome = 0;
    double totalHours = 0;
    int workDays = targetTasks.length;
    Map<String, int> incomeByPlace = {};

    for(var t in targetTasks) {
      int pay = t.salary ?? 0;
      if(t.hasMeal && t.workplace != null) {
        final wp = widget.workplaces.firstWhere((w)=>w.name==t.workplace, orElse: ()=>Workplace(''));
        if(wp.name.isNotEmpty) pay -= wp.mealCost;
      }
      totalIncome += pay;
      totalHours += (t.workHours ?? 0);
      
      if(t.workplace != null) {
        incomeByPlace[t.workplace!] = (incomeByPlace[t.workplace!] ?? 0) + pay;
      }
    }

    double avgHours = workDays > 0 ? totalHours / workDays : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            CupertinoSegmentedControl<int>(
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("日")), 
                1: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("月")), 
                2: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("年"))
              },
              groupValue: _periodMode,
              onValueChanged: (v) => setState(() => _periodMode = v),
            )
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
             IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=>_moveDate(-1)),
             Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=>_moveDate(1)),
          ]),
          const Divider(),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text("総収入 (まかない費控除後)", style: TextStyle(color: Colors.grey)),
                Text("¥${NumberFormat('#,###').format(totalIncome)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Column(children: [const Text("勤務時間"), Text("${totalHours.toStringAsFixed(1)} h", style: const TextStyle(fontWeight: FontWeight.bold))]),
                  Column(children: [const Text("平均時間"), Text("${avgHours.toStringAsFixed(1)} h/日", style: const TextStyle(fontWeight: FontWeight.bold))]),
                  Column(children: [const Text("出勤日数"), Text("$workDays 日", style: const TextStyle(fontWeight: FontWeight.bold))]),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if(incomeByPlace.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text("バイト先別収入", style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            ...incomeByPlace.entries.map((e) {
               double percentage = totalIncome > 0 ? e.value / totalIncome : 0;
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4),
                 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key), Text("¥${NumberFormat('#,###').format(e.value)}")]),
                   const SizedBox(height: 4),
                   LinearProgressIndicator(value: percentage, color: Colors.amber, backgroundColor: Colors.grey.shade200, minHeight: 8),
                 ]),
               );
            }),
          ] else const Text("データがありません", style: TextStyle(color: Colors.grey))
        ],
      ),
    );
  }

  void _moveDate(int dir) {
    setState(() {
      if(_periodMode == 0) _targetDate = _targetDate.add(Duration(days: dir));
      if(_periodMode == 1) _targetDate = DateTime(_targetDate.year, _targetDate.month + dir, 1);
      if(_periodMode == 2) _targetDate = DateTime(_targetDate.year + dir, 1, 1);
    });
  }
}

class TimetableCombinedPage extends StatefulWidget {
  final List<ClassPeriod> timetable;
  final List<Map<String, String>> periodSettings;
  final Function(List<ClassPeriod>, List<Map<String, String>>) onSave;

  const TimetableCombinedPage({
    super.key,
    required this.timetable,
    required this.periodSettings,
    required this.onSave,
  });

  @override
  State<TimetableCombinedPage> createState() => _TimetableCombinedPageState();
}

class _TimetableCombinedPageState extends State<TimetableCombinedPage> {
  late List<ClassPeriod> _localTimetable;
  late List<Map<String, String>> _localSettings;

  @override
  void initState() {
    super.initState();
    _localTimetable = List.from(widget.timetable);
    _localSettings = widget.periodSettings.map((e) => Map<String, String>.from(e)).toList();
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
      Navigator.pop(context); 
    }, child: const Text('一時保存'))]));
  }

  void _selectTime(BuildContext context, TimeOfDay initial, Function(TimeOfDay) onSelected) {
    showCupertinoModalPopup(context: context, builder: (_) => Container(height: 250, color: Colors.white, child: Column(children: [SizedBox(height: 180, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: DateTime(2023,1,1,initial.hour,initial.minute), use24hFormat: true, minuteInterval: 5, onDateTimeChanged: (val) => onSelected(TimeOfDay(hour: val.hour, minute: val.minute)))), CupertinoButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop())])));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('時間割・時間設定'),
          bottom: const TabBar(tabs: [Tab(text: "授業登録"), Tab(text: "時間設定")]),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSave(_localTimetable, _localSettings);
                Navigator.pop(context);
              }, 
              child: const Text("完了", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
            )
          ],
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Container(height: 30, color: Colors.blue.shade50, child: Row(children: [const SizedBox(width: 40), ...["月","火","水","木","金","土"].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))))] )),
                Expanded(
                  child: Column(
                    children: List.generate(5, (periodIndex) {
                      final periodNum = periodIndex + 1;
                      final timeSetting = _localSettings[periodIndex];
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
            ListView.builder(
              itemCount: 5,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final startCtrl = TextEditingController(text: _localSettings[index]['start']);
                final endCtrl = TextEditingController(text: _localSettings[index]['end']);
                return Row(
                  children: [
                    Text("${index + 1}限: "),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: startCtrl, textAlign: TextAlign.center, readOnly: true,
                      onTap: () {
                         TimeOfDay t = TimeOfDay(hour: int.parse(startCtrl.text.split(':')[0]), minute: int.parse(startCtrl.text.split(':')[1]));
                         _selectTime(context, t, (newT) { setState(() { _localSettings[index]['start'] = "${newT.hour.toString().padLeft(2,'0')}:${newT.minute.toString().padLeft(2,'0')}"; }); });
                      },
                    )),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("~")),
                    Expanded(child: TextField(
                      controller: endCtrl, textAlign: TextAlign.center, readOnly: true,
                      onTap: () {
                         TimeOfDay t = TimeOfDay(hour: int.parse(endCtrl.text.split(':')[0]), minute: int.parse(endCtrl.text.split(':')[1]));
                         _selectTime(context, t, (newT) { setState(() { _localSettings[index]['end'] = "${newT.hour.toString().padLeft(2,'0')}:${newT.minute.toString().padLeft(2,'0')}"; }); });
                      },
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}