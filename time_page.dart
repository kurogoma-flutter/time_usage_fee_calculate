import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// 2.1時間は3時間としてカウントする。

class TimeStampPage extends StatefulWidget {
  const TimeStampPage({Key? key}) : super(key: key);

  @override
  _TimeStampPageState createState() => _TimeStampPageState();
}

class _TimeStampPageState extends State<TimeStampPage> {
  /// ///////////////////////////////////////////////////////////////////////////////
  ///                                共通関数
  /// ///////////////////////////////////////////////////////////////////////////////

  // 24時間表記に変換
  String to24hours(time) {
    final hour = time.hour.toString().padLeft(2, "0");
    final min = time.minute.toString().padLeft(2, "0");
    return "$hour:$min";
  }

  // エラーダイアログ
  _errorDialog(String text) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラーメッセージ'),
          content: Text(text),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// ///////////////////////////////////////////////////////////////////////////////
  ///                           日付入力に関するロジック
  /// ///////////////////////////////////////////////////////////////////////////////

  // 今日の日付
  DateFormat dateFormat = DateFormat('yyyy/MM/dd');
  DateTime today = DateTime.now();
  // 開始時間の取得
  TimeOfDay? startTime;
  Future _pickTime(BuildContext context) async {
    // 現在日時を取得
    final initialTime = TimeOfDay.now();
    //TimePickerを呼び出す
    final newTime = await showTimePicker(context: context, initialTime: initialTime);
    //nullチェック
    if (newTime != null) {
      //変数に選択した時刻を格納
      setState(() => startTime = newTime);
    } else {
      return;
    }
  }

  // 終了日時の取得
  TimeOfDay? endTime;
  Future _pickEndTime(BuildContext context) async {
    // デフォルト時間（現在日時）
    final initialTime = TimeOfDay.now();
    //TimePickerを呼び出す
    final newTime = await showTimePicker(context: context, initialTime: initialTime);
    //nullチェック
    if (newTime != null) {
      //変数に選択した時刻を格納
      setState(() => endTime = newTime);
    } else {
      return;
    }
  }

  /// ===============================================================================

  /// ///////////////////////////////////////////////////////////////////////////////
  ///                         合計利用時間算出用ロジック
  /// ///////////////////////////////////////////////////////////////////////////////

  late DateTime? startDateTime; // 開始日時
  late DateTime? endDateTime; // 終了日時
  late DateTime? dayStartTime; // 最終日のdayTime開始日時
  late DateTime? dayEndTime; // 最終日のdayTime終了
  int hourDifference = 0; // 時間差分
  int dayTime = 0; // 昼利用時間
  int nightTime = 0; // 夜利用時間
  final int dayTimeFee = 1000; // 昼間単価
  final int nightTimeFee = 2000; // 夜間単価
  int dayTimeTotal = 0; // 昼間合計
  int nightTimeTotal = 0; // 夜間合計
  int total = 0; // 合計金額

  // Firestoreへの保存処理
  _storeUsageFee() async {
    await FirebaseFirestore.instance.collection('usageFee').add({
      'startTime': Timestamp.fromDate(startDateTime!), // Firestore用の日付変換
      'endTime': Timestamp.fromDate(endDateTime!),
      'dayTime': dayTime,
      'nightTime': nightTime,
      'totalFee': total,
    });
  }

  // 合計金額をダイアログで表示する
  _showResult() async {
    dayTimeTotal = dayTime * dayTimeFee;
    nightTimeTotal = nightTime * nightTimeFee;
    total = dayTimeTotal + nightTimeTotal;

    var result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('合計料金'),
          content: Text('昼間利用時間：$dayTime時間 × 1,000円\n夜間利用時間：$nightTime時間 × 2,000円\n合計$total円です\n以上で確定してよろしいですか？'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(0),
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(1),
            ),
          ],
        );
      },
    );
    if (result == 1) {
      await _storeUsageFee();
      setState(() {
        startTime = null;
        endTime = null;
        dayTime = 0;
        nightTime = 0;
      });
    } else {
      // キャンセルを押したら再計算のため、計算部分だけリセットする
      setState(() {
        dayTime = 0;
        nightTime = 0;
      });
    }
  }

  // 合計時間を計算する
  _calculateTotalTime() {
    // 入力チェック(nullチェック）
    if (startTime == null || endTime == null) {
      return _errorDialog('開始日時と終了日時を入力してください。');
    }
    // 日時データを加工して受け取る（算出用）
    var date;
    var sTime;
    var eTime;
    date = dateFormat.format(today).split('/');
    sTime = to24hours(startTime).split(':');
    eTime = to24hours(endTime).split(':');

    // DateTimeに変換
    startDateTime = DateTime(int.parse(date[0]), int.parse(date[1]), int.parse(date[2]), int.parse(sTime[0]), int.parse(sTime[1]));
    endDateTime = DateTime(int.parse(date[0]), int.parse(date[1]), int.parse(date[2]), int.parse(eTime[0]), int.parse(eTime[1]));
    dayStartTime = DateTime(int.parse(date[0]), int.parse(date[1]), int.parse(date[2]), 9, 0);
    dayEndTime = DateTime(int.parse(date[0]), int.parse(date[1]), int.parse(date[2]), 18, 0);
    // 開始時間が終了時間を上回っていた場合処理を中断
    if (startDateTime!.isAfter(endDateTime!)) {
      return _errorDialog('開始時間は終了時間より前にしてください。');
    }
    // 時間単位で差分取得
    hourDifference = (endDateTime!.difference(startDateTime!).inMinutes / 60).ceil();

    /*** *** *** 時間帯別計算処理 *** *** ***/

    // 開始日時が9時以前
    if (startDateTime!.isBefore(dayStartTime!)) {
      // 終了日時が9時前
      if (endDateTime!.isBefore(dayStartTime!)) {
        // 日中利用なし。夜間 => 開始 ~ 終了
        nightTime = hourDifference;
      }
      // 終了日時が18時前
      else if (endDateTime!.isAfter(dayStartTime!) && endDateTime!.isBefore(dayEndTime!)) {
        // 日中利用 => 9:00 ~ 終了時間
        dayTime = ((endDateTime!.difference(dayStartTime!).inMinutes) / 60).ceil();
        // 夜間利用 => 開始時間 ~ 9:00
        nightTime = (dayStartTime!.difference(startDateTime!).inMinutes / 60).ceil();
      }
      // 終了日時が18時以降
      else if (endDateTime!.isAfter(dayEndTime!)) {
        // 日中利用 => フル
        dayTime = 9;
        // 夜間利用 => その他の時間
        // 昼間利用前の時間
        int nightBeforeDayTime = (dayStartTime!.difference(startDateTime!).inMinutes);
        // 昼間利用あとの時間
        int nightAfterDayTime = (endDateTime!.difference(dayEndTime!).inMinutes);
        // 合計し、1時間をオーバーしたら繰り上げ
        nightTime = ((nightBeforeDayTime + nightAfterDayTime) / 60).ceil();
      }
      return _showResult();
    }
    // 開始日時が9時 ~ 18時
    else if ((startDateTime!.isAfter(dayStartTime!) || startDateTime!.isAtSameMomentAs(dayStartTime!)) &&
        (startDateTime!.isBefore(dayEndTime!) || startDateTime!.isAtSameMomentAs(dayEndTime!))) {
      // 終了日時が18時前
      if (endDateTime!.isAfter(dayStartTime!) && (endDateTime!.isBefore(dayEndTime!) || endDateTime!.isAtSameMomentAs(dayEndTime!))) {
        // 夜間利用なし。日中利用 => 差分
        dayTime = hourDifference;
      }
      // 終了日時が18時以降
      else if (endDateTime!.isAfter(dayEndTime!)) {
        // 日中利用 => 開始日〜18:00
        dayTime = (dayEndTime!.difference(startDateTime!).inMinutes / 60).ceil();
        // 夜間利用 => 18:00〜終了時間
        nightTime = (endDateTime!.difference(dayEndTime!).inMinutes / 60).ceil();
      }
      return _showResult();
    }
    // 開始日時が18時以降
    else if (startDateTime!.isAfter(dayEndTime!) || startDateTime!.isAtSameMomentAs(dayEndTime!)) {
      // 差分だけ取得（夜しかありえない）
      nightTime = hourDifference;
      return _showResult();
    } else {
      print(startDateTime);
      print(endDateTime);
      print(dayTime);
      print(nightTime);
      return _errorDialog('予期せぬ処理が発生しました。');
    }
  }

  /// ===============================================================================
  ///                             Widget表示領域
  /// ###############################################################################
  @override
  Widget build(BuildContext context) {
    // メディアクエリの取得
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('料金計算'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            '利用日',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              dateFormat.format(today).toString(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              /// 開始日時エリア
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// 開始日時タイトル
                  const Padding(
                    padding: EdgeInsets.only(top: 30, bottom: 10),
                    child: Center(
                      child: Text(
                        '開始時間',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  /// 開始日時選択ボタン
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    width: size.width * 0.4,
                    height: 50,
                    color: const Color(0xFFfffff0),
                    child: ElevatedButton(
                      onPressed: () {
                        _pickTime(context);
                      },
                      child: const Text(
                        '時間選択',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.pinkAccent,
                        onPrimary: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),

                  /// 開始日時テキストボックス
                  Text(
                    startTime != null ? to24hours(startTime) : "時間を選択",
                    style: const TextStyle(
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),

              /// 終了日時エリア
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// 終了日時タイトル
                  const Padding(
                    padding: EdgeInsets.only(top: 30, bottom: 10),
                    child: Center(
                      child: Text(
                        '終了時間',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  /// 終了日時選択ボタン
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    width: size.width * 0.4,
                    height: 50,
                    color: const Color(0xFFfffff0),
                    child: ElevatedButton(
                      onPressed: () {
                        _pickEndTime(context);
                      },
                      child: const Text(
                        '時間選択',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.deepOrangeAccent,
                        onPrimary: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),

                  /// 終了日時のテキスト
                  Text(
                    endTime != null ? to24hours(endTime) : "時間を選択",
                    style: const TextStyle(
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),

            ///  実行ボタン
            child: SizedBox(
              width: size.width * 0.7,
              height: 80,
              child: ElevatedButton(
                onPressed: () {
                  _calculateTotalTime();
                },
                child: const Text(
                  '料金計算をする',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
                ),
                style: ElevatedButton.styleFrom(
                  primary: Colors.cyan,
                  onPrimary: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
