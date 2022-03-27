# time_usage_fee_calculate
利用料金を計算し、Firestoreに保存するアプリケーションです。

# 画面

<table>
  <tr>
    <th>初期表示</th>
    <th>時間選択</th>
    <th>計算結果</th>
  </tr>
  <tr>
    <td>
      <img width="300" src="https://user-images.githubusercontent.com/67848399/160288188-855fdaf0-74ea-47e5-9273-35c15cb7e863.png">
    </td>
    <td>
      <img width="300" src="https://user-images.githubusercontent.com/67848399/160288190-c164f914-d624-40d9-a76c-a0e333ba2a54.png">
    </td>
    <td>
      <img width="300" src="https://user-images.githubusercontent.com/67848399/160288192-2c4c6b69-c12f-44bf-bcef-0352ac32dcc7.png">
    </td>
  </tr>
</table>

# コード
主にDateTime型に対して色々な操作を行なったため、そこを中心に取り上げます。

## 仕様
- 昼間時間（9:00 ~ 18:00）に利用した場合、1000円/h、それ以外は2000円/hで計算
- 2.1hであった場合、3hに繰り上げ

### パッケージ
日付操作でお馴染みのintlを用いています。
```dart
import 'package:intl/intl.dart';
```
<https://pub.dev/packages/intl>

### 24h表記にする関数
DateTimeは12h表記のため、24h表記に変換する関数を作成しました。
```dart
String to24hours(time) {
  final hour = time.hour.toString().padLeft(2, "0");
  final min = time.minute.toString().padLeft(2, "0");
  return "$hour:$min";
}
```

### 時間の取得
`showTimePicker`を用いて時間取得を行いました。
```dart
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
```

### DateTimeの定義
日付型は以下のようにして生成可能です。
左から、年月日時分秒と生成されていきます。

```dart
DateTime date = DateTime(2022,2,10,12,10);
```

### 時間帯識別
- 0:00 ~ 9:00 => 夜間
- 9:00 ~ 18:00 => 昼間
- 18:00 ~ 23:59 => 夜間
上記を識別するために比較の関数を用いました。

#### 〜より前
```dart
startDateTime!.isBefore(dayStartTime!)
```

#### 〜より後
```dart
endDateTime!.isAfter(dayEndTime!)
```

#### 〜と同じ
`isBefore()`と`isAfter()`は、同じ時間だとfalseを返します。
```dart
startDateTime!.isAtSameMomentAs(dayStartTime!)
```

### 差分取得
料金計算のため、差分取得も行いました。
時間単位で差分取得も可能ですが、そうすると0.1h => 1とする計算がうまくいかなかったため、
分単位で差分を取得してから繰り上げ処理を行いました。
```dart
hourDifference = (endDateTime!.difference(startDateTime!).inMinutes / 60).ceil();
```
