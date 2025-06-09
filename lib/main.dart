import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
// تهيئة Firebase قبل تشغيل التطبيق
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(LostFoundApp());
}
// =============== نموذج البيانات ===============
enum ReportType { lost, found }
class Report {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final ReportType type;
  final IconData icon;
  final String? imageUrl;
  final String ownerId;
  Report({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.type,
    required this.icon,
    this.imageUrl,
    required this.ownerId,
  });

  // تحويل من Firebase إلى كائن Report
  // تستخدم للقراءةfromFirestore
  factory Report.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] == 'lost' ? ReportType.lost : ReportType.found,
      icon: _getIconForCategory(data['category'] ?? 'other'),
      imageUrl: data['imageUrl'],
      ownerId: data['ownerId'] ?? '',
    );
  }

  // تحويل كائن Report إلى Map لتخزينه في Firebase
  // toFirestore تستخدم للإرسال والتخزين
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': Timestamp.fromDate(date),
      'type': type == ReportType.lost ? 'lost' : 'found',
      'category': _getCategoryFromIcon(icon),
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // تحديد الأيقونة حسب الفئة
  static IconData _getIconForCategory(String category) {
    switch (category) {
      case 'electronics':
        return Icons.smartphone;
      case 'personal':
        return Icons.wallet;
      case 'documents':
        return Icons.credit_card;
      case 'keys':
        return Icons.key;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.help_outline;
    }
  }

  // تحديد الفئة من الأيقونة
  static String _getCategoryFromIcon(IconData icon) {
    if (icon == Icons.smartphone) return 'electronics';
    if (icon == Icons.wallet) return 'personal';
    if (icon == Icons.credit_card) return 'documents';
    if (icon == Icons.key) return 'keys';
    if (icon == Icons.pets) return 'pets';
    return 'other';
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool read;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.read = false,
  });

  // تحويل من Firebase إلى كائن Message
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] ?? false,
    );
  }

  // تحويل كائن Message إلى Map لتخزينه في Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String type;
  final String userId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
    required this.type,
    required this.userId,
  });

  // تحويل من Firebase إلى كائن NotificationModel
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] ?? false,
      type: data['type'] ?? 'general',
      userId: data['userId'] ?? '',
    );
  }

  // تحويل كائن NotificationModel إلى Map لتخزينه في Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      'type': type,
      'userId': userId,
    };
  }

  // تحديد الأيقونة حسب نوع الإشعار
  IconData get icon {
    switch (type) {
      case 'match':
        return Icons.pan_tool;
      case 'message':
        return Icons.message;
      case 'nearby':
        return Icons.notifications;
      case 'found':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  // تحديد لون الأيقونة حسب نوع الإشعار
  Color get iconColor {
    switch (type) {
      case 'match':
        return Colors.green;
      case 'message':
        return Colors.blue;
      case 'nearby':
        return Colors.purple;
      case 'found':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}

class Conversation {
  final String id;
  final String userId;
  final String userName;
  final List<Message> messages;
  final bool isOnline;
  final DateTime lastActive;
  final String reportId;

  Conversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.messages,
    this.isOnline = false,
    required this.lastActive,
    required this.reportId,
  });

  // تحويل من Firebase إلى كائن Conversation
  factory Conversation.fromFirestore(
      DocumentSnapshot doc, List<Message> messages) {
    Map data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      messages: messages,
      isOnline: data['isOnline'] ?? false,
      lastActive:
          (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reportId: data['reportId'] ?? '',
    );
  }

  // الحصول على آخر رسالة في المحادثة
  Message? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoURL;
  final bool isOnline;
  final DateTime lastActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoURL,
    this.isOnline = false,
    required this.lastActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      isOnline: data['isOnline'] ?? false,
      lastActive:
          (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// =============== خدمة Firebase ===============

class FirebaseService {
  // المتغيرات الرئيسية
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // المجموعات في Firestore
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _reports => _firestore.collection('reports');
  CollectionReference get _messages => _firestore.collection('messages');
  CollectionReference get _conversations =>
      _firestore.collection('conversations');
  CollectionReference get _notifications =>
      _firestore.collection('notifications');
  // المستخدم الحالي
  User? get currentUser => _auth.currentUser;
  String get currentUserId => currentUser?.uid ?? '';
  // ========== مصادقة المستخدمين ==========
  // الحصول على قائمة المستخدمين
  Future<List<UserModel>> getUsers() async {
    try {
      //الحصول على بيانات المستخدمين ماعدا المستخدم الحالي
      QuerySnapshot snapshot = await _users.get();
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.id != currentUserId) // استبعاد المستخدم الحالي
          .toList();
    } catch (e) {
      print('خطأ في جلب المستخدمين: $e');
      return [];
    }
  }
  // الحصول على معلومات مستخدم
  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _users.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب بيانات المستخدم: $e');
      return null;
    }
  }
  // تسجيل مستخدم جديد
  Future<UserCredential> signUp(
      String email, String password, String name, String phone) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // تخزين بيانات المستخدم في Firestore
      await _users.doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'authProvider': 'email',
      });
      // تحديث اسم المستخدم في Firebase Auth
      await userCredential.user!.updateDisplayName(name);
      return userCredential;
    } catch (e) {
      print('خطأ في تسجيل المستخدم: $e');
      rethrow;
    }
  }

  // تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // تحديث وقت آخر دخول في Firestore
      await _users.doc(userCredential.user!.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      print('خطأ في تسجيل الدخول: $e');
      rethrow;
    }
  }

  // تسجيل الدخول باستخدام حساب Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // بدء عملية تسجيل الدخول باستخدام Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // إذا لم يتم اختيار حساب Google
      if (googleUser == null) {
        throw Exception('تم إلغاء تسجيل الدخول باستخدام Google');
      }

      // الحصول على تفاصيل المصادقة من الطلب
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // إنشاء بيانات اعتماد جديدة لـ Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول باستخدام البيانات في Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // التحقق مما إذا كان هذا مستخدم جديد
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // إنشاء وثيقة مستخدم جديدة في Firestore
        await _users.doc(userCredential.user!.uid).set({
          'name': userCredential.user!.displayName ?? '',
          'email': userCredential.user!.email ?? '',
          'phone': userCredential.user!.phoneNumber ?? '',
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'authProvider': 'google',
        });
      } else {
        // تحديث وقت آخر دخول للمستخدم الحالي
        await _users.doc(userCredential.user!.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
          'photoURL':
              userCredential.user!.photoURL, // تحديث URL الصورة في حالة تغييرها
        });
      }

      return userCredential;
    } catch (e) {
      print('خطأ في تسجيل الدخول باستخدام Google: $e');
      rethrow;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      // تسجيل الخروج من حساب Google إذا كان مستخدمًا
      await _googleSignIn.signOut();

      // تسجيل الخروج من Firebase Auth
      await _auth.signOut();
    } catch (e) {
      print('خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }

  // ========== إدارة البلاغات ==========

  // الحصول على جميع البلاغات
  Stream<List<Report>> getReports() {
    return _reports
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    });
  }

  // الحصول على بلاغات المستخدم الحالي
  Stream<List<Report>> getUserReports() {
    return _reports
        .where('ownerId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    });
  }

  // إضافة بلاغ جديد
  Future<DocumentReference> addReport(Report report, File? imageFile) async {
    try {
      String? imageUrl;

      // رفع الصورة إلى Storage إذا وجدت
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile);
      }

      // إنشاء نسخة من البلاغ مع تحديث رابط الصورة
      final reportData = report.toFirestore();
      reportData['imageUrl'] = imageUrl;

      // إضافة البلاغ إلى Firestore
      return await _reports.add(reportData);
    } catch (e) {
      print('خطأ في إضافة البلاغ: $e');
      rethrow;
    }
  }

  // تحديث بلاغ
  Future<void> updateReport(
      String reportId, Map<String, dynamic> data, File? newImageFile) async {
    try {
      // جلب بيانات البلاغ الحالية
      DocumentSnapshot reportDoc = await _reports.doc(reportId).get();
      Map<String, dynamic> reportData =
          reportDoc.data() as Map<String, dynamic>;

      // تحديث الصورة إذا تم توفير صورة جديدة
      if (newImageFile != null) {
        // حذف الصورة القديمة إذا كانت موجودة
        if (reportData['imageUrl'] != null &&
            reportData['imageUrl'].toString().isNotEmpty) {
          try {
            String imagePath = reportData['imageUrl']
                .toString()
                .split('report_images/')
                .last
                .split('?')
                .first;
            await _storage.ref('report_images/$imagePath').delete();
          } catch (e) {
            print('خطأ في حذف الصورة القديمة: $e');
          }
        }

        // رفع الصورة الجديدة
        String newImageUrl = await _uploadImage(newImageFile);
        data['imageUrl'] = newImageUrl;
      }

      // تحديث بيانات البلاغ
      await _reports.doc(reportId).update(data);
    } catch (e) {
      print('خطأ في تحديث البلاغ: $e');
      rethrow;
    }
  }

  // حذف بلاغ
  Future<void> deleteReport(String reportId) async {
    try {
      // الحصول على بيانات البلاغ قبل حذفه
      DocumentSnapshot reportDoc = await _reports.doc(reportId).get();
      Map<String, dynamic> reportData =
          reportDoc.data() as Map<String, dynamic>;

      // حذف الصورة من Storage إذا وجدت
      if (reportData['imageUrl'] != null &&
          reportData['imageUrl'].toString().isNotEmpty) {
        try {
          // استخراج مسار الصورة من URL
          String imagePath = reportData['imageUrl']
              .toString()
              .split('report_images/')
              .last
              .split('?')
              .first;
          await _storage.ref('report_images/$imagePath').delete();
          print('تم حذف الصورة: $imagePath');
        } catch (e) {
          print('خطأ في حذف الصورة: $e');
          // نستمر في حذف البلاغ حتى لو فشل حذف الصورة
        }
      }

      // حذف البلاغ من Firestore
      await _reports.doc(reportId).delete();
    } catch (e) {
      print('خطأ في حذف البلاغ: $e');
      rethrow;
    }
  }

  // البحث في البلاغات
  Future<List<Report>> searchReports(
      {String? query, ReportType? type, String? category}) async {
    try {
      Query ref = _reports;

      // تصفية حسب النوع
      if (type != null) {
        ref = ref.where('type',
            isEqualTo: type == ReportType.lost ? 'lost' : 'found');
      }

      // تصفية حسب الفئة
      if (category != null && category != 'all') {
        ref = ref.where('category', isEqualTo: category);
      }

      // جلب البيانات
      QuerySnapshot snapshot = await ref.get();

      // تحويل البيانات إلى كائنات Report وتصفيتها حسب كلمات البحث إن وجدت
      List<Report> reports =
          snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();

      // تصفية حسب النص في حالة وجوده
      if (query != null && query.isNotEmpty) {
        reports = reports.where((report) {
          return report.title.toLowerCase().contains(query.toLowerCase()) ||
              report.description.toLowerCase().contains(query.toLowerCase()) ||
              report.location.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }

      return reports;
    } catch (e) {
      print('خطأ في البحث عن البلاغات: $e');
      return [];
    }
  }

  // ========== إدارة المحادثات والرسائل ==========

  // إنشاء محادثة جديدة مع مستخدم محدد
  Future<String> createDirectConversation(String userId) async {
    try {
      // جلب معلومات المستخدم الآخر
      DocumentSnapshot userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('المستخدم غير موجود');
      }

      String otherUserName =
          (userDoc.data() as Map<String, dynamic>)['name'] ?? 'المستخدم';

      // البحث عن محادثة موجودة بالفعل (اتصال مباشر بدون تقرير)
      QuerySnapshot existingConversations = await _conversations
          .where('participants', arrayContains: currentUserId)
          .where('isDirect', isEqualTo: true)
          .get();

      for (var doc in existingConversations.docs) {
        List<dynamic> participants =
            (doc.data() as Map<String, dynamic>)['participants'];
        if (participants.contains(userId)) {
          return doc.id;
        }
      }

      // إنشاء محادثة جديدة
      DocumentReference conversationRef = await _conversations.add({
        'participants': [currentUserId, userId],
        'participantNames': {
          currentUserId: currentUser?.displayName ?? 'المستخدم',
          userId: otherUserName
        },
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isDirect': true,
        'reportId': '', // فارغ لأنها محادثة مباشرة
      });

      // إنشاء إشعار للمستخدم الآخر
      await _notifications.add({
        'userId': userId,
        'title': 'محادثة جديدة',
        'message': '${currentUser?.displayName ?? "مستخدم"} بدأ محادثة معك',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'message',
        'conversationId': conversationRef.id
      });

      return conversationRef.id;
    } catch (e) {
      print('خطأ في إنشاء محادثة مباشرة: $e');
      rethrow;
    }
  }

  // إنشاء أو الحصول على محادثة بين المستخدم الحالي ومستخدم آخر بخصوص بلاغ معين
  Future<String> getOrCreateConversation(
      String otherUserId, String otherUserName, String reportId) async {
    try {
      // البحث عن محادثة موجودة
      QuerySnapshot snapshot = await _conversations
          .where('reportId', isEqualTo: reportId)
          .where('participants', arrayContains: currentUserId)
          .get();
      // التحقق مما إذا كانت هناك محادثة بالفعل مع نفس المستخدم ونفس البلاغ
      for (var doc in snapshot.docs) {
        List<dynamic> participants =
            (doc.data() as Map<String, dynamic>)['participants'];
        if ((doc.data() as Map)['participants'].contains(otherUserId)) {
          return doc.id;
        }
      }

      // إنشاء محادثة جديدة إذا لم تكن موجودة
      DocumentReference conversationRef = await _conversations.add({
        'participants': [currentUserId, otherUserId],
        'participantNames': {
          currentUserId: currentUser?.displayName ?? 'المستخدم',
          otherUserId: otherUserName
        },
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'reportId': reportId,
        'isDirect': false,
      });

      // إنشاء إشعار للمستخدم الآخر
      await _notifications.add({
        'userId': otherUserId,
        'title': 'محادثة جديدة',
        'message':
            '${currentUser?.displayName ?? "مستخدم"} يريد التواصل معك بخصوص بلاغك',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'message',
        'conversationId': conversationRef.id,
        'reportId': reportId
      });

      return conversationRef.id;
    } catch (e) {
      print('خطأ في إنشاء المحادثة: $e');
      rethrow;
    }
  }

  // إرسال رسالة
  Future<void> sendMessage(String conversationId, String content) async {
    try {
      // جلب معلومات المحادثة
      DocumentSnapshot conversationDoc =
          await _conversations.doc(conversationId).get();
      Map<String, dynamic> conversationData =
          conversationDoc.data() as Map<String, dynamic>;

      // التأكد من أن المستخدم جزء من هذه المحادثة
      List<dynamic> participants = conversationData['participants'];
      if (!participants.contains(currentUserId)) {
        throw Exception('المستخدم ليس جزءًا من هذه المحادثة');
      }

      // الحصول على المستخدم الآخر في المحادثة
      String otherUserId = participants.firstWhere((id) => id != currentUserId);

      // إضافة الرسالة إلى Firestore
      await _messages.add({
        'conversationId': conversationId,
        'senderId': currentUserId,
        'senderName': currentUser?.displayName ?? 'المستخدم',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // تحديث المحادثة بآخر رسالة
      await _conversations.doc(conversationId).update({
        'lastMessage': content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // إنشاء إشعار للمستخدم الآخر
      await _notifications.add({
        'userId': otherUserId,
        'title': 'رسالة جديدة',
        'message': '${currentUser?.displayName ?? 'المستخدم'} أرسل لك رسالة',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'message',
        'conversationId': conversationId
      });
    } catch (e) {
      print('خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  // الحصول على رسائل محادثة معينة
  Stream<List<Message>> getMessages(String conversationId) {
    return _messages
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // الحصول على محادثات المستخدم الحالي
  Stream<List<Conversation>> getConversations() {
    return _conversations
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Conversation> conversations = [];

      for (var doc in snapshot.docs) {
        // جلب آخر 20 رسالة لكل محادثة
        QuerySnapshot messagesSnapshot = await _messages
            .where('conversationId', isEqualTo: doc.id)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        List<Message> messages = messagesSnapshot.docs
            .map((msgDoc) => Message.fromFirestore(msgDoc))
            .toList()
            .reversed
            .toList(); // عكس الترتيب ليكون تصاعديًا

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> participants = data['participants'];
        String userId = participants.firstWhere((id) => id != currentUserId,
            orElse: () => '');
        String userName = '';

        if (userId.isNotEmpty && data['participantNames'] != null) {
          userName = data['participantNames'][userId] ?? 'المستخدم';
        }

        conversations.add(Conversation(
          id: doc.id,
          userId: userId,
          userName: userName,
          messages: messages,
          isOnline: false, // يمكن تحديث هذا لاحقًا
          lastActive: (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          reportId: data['reportId'] ?? '',
        ));
      }

      return conversations;
    });
  }

  // ========== إدارة الإشعارات ==========

  // الحصول على إشعارات المستخدم الحالي
  Stream<List<NotificationModel>> getNotifications() {
    return _notifications
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  // تحديث حالة الإشعار (مقروء)
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notifications.doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('خطأ في تحديث حالة الإشعار: $e');
      rethrow;
    }
  }

  // تحديث حالة جميع الإشعارات (مقروءة)
  Future<void> markAllNotificationsAsRead() async {
    try {
      WriteBatch batch = _firestore.batch();

      QuerySnapshot notificationsSnapshot = await _notifications
          .where('userId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      print('خطأ في تحديث حالة جميع الإشعارات: $e');
      rethrow;
    }
  }

  // ========== وظائف مساعدة ==========

  // جلب بيانات مستخدم بمعرف معين
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      DocumentSnapshot userDoc = await _users.doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('خطأ في جلب معلومات المستخدم: $e');
      return null;
    }
  }

  // رفع صورة إلى Firebase Storage وإرجاع الرابط
  Future<String> _uploadImage(File imageFile) async {
    try {
      // إنشاء مسار فريد للصورة
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUserId}.jpg';
      Reference storageRef = _storage.ref().child('report_images/$fileName');

      // رفع الصورة
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;

      // الحصول على رابط التنزيل
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      rethrow;
    }
  }

  // التحقق مما إذا كان هناك مطابقة محتملة للبلاغ
  Future<void> checkForPotentialMatches(String reportId) async {
    try {
      // الحصول على البلاغ
      DocumentSnapshot reportDoc = await _reports.doc(reportId).get();
      Report report = Report.fromFirestore(reportDoc);

      // البحث عن بلاغات مشابهة
      Query matchQuery = _reports
          .where('type',
              isEqualTo: report.type == ReportType.lost ? 'found' : 'lost')
          .where('category',
              isEqualTo: Report._getCategoryFromIcon(report.icon));

      QuerySnapshot matchSnapshot = await matchQuery.get();
      List<Report> potentialMatches = matchSnapshot.docs
          .map((doc) => Report.fromFirestore(doc))
          .where((match) {
        // التحقق من التقارب الزمني والمكاني
        bool dateClose =
            (match.date.difference(report.date).inDays).abs() <= 14;
        // هنا يمكن أيضًا إضافة منطق للتحقق من قرب الموقع
        return dateClose;
      }).toList();

      // إرسال إشعارات للمطابقات المحتملة
      for (var match in potentialMatches) {
        await _notifications.add({
          'userId': report.ownerId,
          'title': 'تم العثور على غرض مشابه',
          'message': 'وجدنا بلاغ مطابق محتمل لـ "${report.title}"',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'match',
          'reportId': match.id,
        });

        await _notifications.add({
          'userId': match.ownerId,
          'title': 'تم العثور على غرض مشابه',
          'message': 'وجدنا بلاغ مطابق محتمل لـ "${match.title}"',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'match',
          'reportId': reportId,
        });
      }
    } catch (e) {
      print('خطأ في التحقق من المطابقات المحتملة: $e');
      rethrow;
    }
  }
}

// =============== مزود البيانات ===============

class AppDataProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  List<Report> _reports = [];
  List<NotificationModel> _notifications = [];
  List<Conversation> _conversations = [];
  List<UserModel> _users = [];

  var currentUser;

  // الحالة
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseService.currentUser != null;
  String get userName => _firebaseService.currentUser?.displayName ?? '';
  String? get userPhotoUrl => _firebaseService.currentUser?.photoURL;

  // البيانات
  List<Report> get reports => _reports;
  List<Report> get lostReports =>
      _reports.where((r) => r.type == ReportType.lost).toList();
  List<Report> get foundReports =>
      _reports.where((r) => r.type == ReportType.found).toList();
  List<NotificationModel> get notifications => _notifications;
  List<Conversation> get conversations => _conversations;
  List<UserModel> get users => _users;
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.read).length;

  // كل دالة تستمع لتغييرات البيانات وتحدثها مباشرة
  // الاستماع للتغييرات
  void initListeners() {
    if (isLoggedIn) {
      _listenToReports();
      _listenToNotifications();
      _listenToConversations();
      _loadUsers();
    }
  }

  void _listenToReports() {
    _firebaseService.getReports().listen((updatedReports) {
      _reports = updatedReports;
      notifyListeners();
    });
  }

  void _listenToNotifications() {
    _firebaseService.getNotifications().listen((updatedNotifications) {
      _notifications = updatedNotifications;
      notifyListeners();
    });
  }

  void _listenToConversations() {
    _firebaseService.getConversations().listen((updatedConversations) {
      _conversations = updatedConversations;
      notifyListeners();
    });
  }

  // تحميل قائمة المستخدمين
  Future<void> _loadUsers() async {
    try {
      _users = await _firebaseService.getUsers();
      notifyListeners();
    } catch (e) {
      print('خطأ في تحميل المستخدمين: $e');
    }
  }

  // إنشاء محادثة مع مستخدم محدد
  Future<String?> createDirectConversation(String userId) async {
    _setLoading(true);
    try {
      if (!isLoggedIn) return null;

      final conversationId =
          await _firebaseService.createDirectConversation(userId);
      return conversationId;
    } catch (e) {
      print('خطأ في إنشاء محادثة مباشرة: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // تسجيل المستخدمين
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _firebaseService.signIn(email, password);
      initListeners();
      return true;
    } catch (e) {
      print('خطأ في تسجيل الدخول: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(
      String email, String password, String name, String phone) async {
    _setLoading(true);
    try {
      await _firebaseService.signUp(email, password, name, phone);
      initListeners();
      return true;
    } catch (e) {
      print('خطأ في إنشاء الحساب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // تسجيل الدخول باستخدام Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      await _firebaseService.signInWithGoogle();
      initListeners();
      return true;
    } catch (e) {
      print('خطأ في تسجيل الدخول باستخدام Google: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _firebaseService.signOut();
      _reports = [];
      _notifications = [];
      _conversations = [];
      _users = [];
      notifyListeners();
    } catch (e) {
      print('خطأ في تسجيل الخروج: $e');
    } finally {
      _setLoading(false);
    }
  }

  // إدارة البلاغات
  Future<bool> addReport(String title, String description, String location,
      DateTime date, ReportType type, String category, File? imageFile) async {
    _setLoading(true);
    try {
      if (!isLoggedIn) return false;

      // إنشاء كائن Report
      Report report = Report(
        id: '', // سيتم توليد هذا بواسطة Firestore
        title: title,
        description: description,
        location: location,
        date: date,
        type: type,
        icon: Report._getIconForCategory(category),
        ownerId: _firebaseService.currentUserId,
      );

      // إضافة البلاغ إلى Firestore
      DocumentReference docRef =
          await _firebaseService.addReport(report, imageFile);

      // التحقق من المطابقات المحتملة
      await _firebaseService.checkForPotentialMatches(docRef.id);

      return true;
    } catch (e) {
      print('خطأ في إضافة البلاغ: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // تعديل بلاغ
  Future<bool> updateReport(
      String reportId,
      String title,
      String description,
      String location,
      DateTime date,
      ReportType type,
      String category,
      File? newImageFile,
      bool keepExistingImage) async {
    _setLoading(true);
    try {
      if (!isLoggedIn) return false;

      // التحقق من وجود البلاغ وأنه مملوك للمستخدم الحالي
      final report = _reports.firstWhere((r) => r.id == reportId,
          orElse: () => Report(
              id: '',
              title: '',
              description: '',
              location: '',
              date: DateTime.now(),
              type: ReportType.lost,
              icon: Icons.help_outline,
              ownerId: ''));

      if (report.id.isEmpty) return false;
      if (report.ownerId != _firebaseService.currentUserId) return false;

      // إعداد بيانات التحديث
      Map<String, dynamic> updateData = {
        'title': title,
        'description': description,
        'location': location,
        'date': Timestamp.fromDate(date),
        'type': type == ReportType.lost ? 'lost' : 'found',
        'category':
            Report._getCategoryFromIcon(Report._getIconForCategory(category)),
      };

      // إذا كان المستخدم لا يريد الاحتفاظ بالصورة الحالية، وليس هناك صورة جديدة
      if (!keepExistingImage && newImageFile == null) {
        updateData['imageUrl'] = '';
      }

      // تحديث البلاغ في Firestore
      await _firebaseService.updateReport(
          reportId, updateData, keepExistingImage ? null : newImageFile);

      return true;
    } catch (e) {
      print('خطأ في تعديل البلاغ: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // حذف بلاغ
  Future<bool> deleteReport(String reportId) async {
    _setLoading(true);
    try {
      if (!isLoggedIn) return false;

      // التحقق من وجود البلاغ وأنه مملوك للمستخدم الحالي
      final report = _reports.firstWhere((r) => r.id == reportId,
          orElse: () => Report(
              id: '',
              title: '',
              description: '',
              location: '',
              date: DateTime.now(),
              type: ReportType.lost,
              icon: Icons.help_outline,
              ownerId: ''));

      if (report.id.isEmpty) return false;
      if (report.ownerId != _firebaseService.currentUserId) return false;

      // حذف البلاغ من Firestore
      await _firebaseService.deleteReport(reportId);

      return true;
    } catch (e) {
      print('خطأ في حذف البلاغ: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Report>> searchReports(
      String? query, ReportType? type, String? category) async {
    _setLoading(true);
    try {
      return await _firebaseService.searchReports(
        query: query,
        type: type,
        category: category,
      );
    } catch (e) {
      print('خطأ في البحث عن البلاغات: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // إدارة المحادثات
  Future<bool> contactReportOwner(Report report) async {
    _setLoading(true);
    try {
      if (!isLoggedIn) return false;

      // التحقق من أن المستخدم ليس صاحب البلاغ
      if (report.ownerId == _firebaseService.currentUserId) {
        return false;
      }

      // الحصول على معلومات المالك
      final ownerInfo = await _firebaseService.getUserInfo(report.ownerId);
      final ownerName = ownerInfo?['name'] ?? 'صاحب البلاغ';

      // إنشاء أو الحصول على محادثة
      await _firebaseService.getOrCreateConversation(
        report.ownerId,
        ownerName,
        report.id,
      );

      return true;
    } catch (e) {
      print('خطأ في التواصل مع صاحب البلاغ: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage(String conversationId, String content) async {
    try {
      if (!isLoggedIn || content.trim().isEmpty) return false;

      await _firebaseService.sendMessage(conversationId, content);
      return true;
    } catch (e) {
      print('خطأ في إرسال الرسالة: $e');
      return false;
    }
  }

  // إدارة الإشعارات
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firebaseService.markNotificationAsRead(notificationId);
    } catch (e) {
      print('خطأ في تحديث حالة الإشعار: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _firebaseService.markAllNotificationsAsRead();
    } catch (e) {
      print('خطأ في تحديث حالة جميع الإشعارات: $e');
    }
  }

  // التقاط صورة
  Future<File?> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  // تغيير حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// =============== الترجمات ===============

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Lost & Found',
      'home': 'Home',
      'addReport': 'Add Report',
      'search': 'Search',
      'notifications': 'Notifications',
      'messages': 'Messages',
      'darkMode': 'Dark Mode',
      'language': 'العربية',
      'account': 'My Account',
      'nearbyLostItems': 'Nearby Lost Items',
      'nearbyFoundItems': 'Nearby Found Items',
      'foundItems': 'Found',
      'myReports': 'My Reports',
      'recentReports': 'Recent Reports',
      'viewAll': 'View All',
      'loadMore': 'Load More',
      'lost': 'Lost',
      'found': 'Found',
      'contact': 'Contact',
      'viewDetails': 'View Details',
      'reportType': 'Report Type',
      'itemCategory': 'Item Category',
      'itemTitle': 'Item Title',
      'itemDescription': 'Item Description',
      'itemDate': 'Date',
      'itemLocation': 'Location',
      'itemImage': 'Image (Optional)',
      'uploadImage': 'Upload Image',
      'submitReport': 'Submit Report',
      'searchPlaceholder': 'Search by keywords...',
      'allCategories': 'All Categories',
      'allTypes': 'All',
      'lostItems': 'Lost Items',
      // ignore: equal_keys_in_map
      'foundItems': 'Found Items',
      'noResults': 'No matching results',
      'selectConversation': 'Select a Conversation',
      'typeMessage': 'Type your message here...',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'forgotPassword': 'Forgot password?',
      'fullName': 'Full Name',
      'phoneNumber': 'Phone Number',
      'loginWith': 'Or login with',
      'selectCategory': 'Select Category',
      'browseFiles': 'Browse Files',
      'electronics': 'Electronics (Phones, Devices)',
      'personal': 'Personal Items (Wallets, Bags)',
      'documents': 'Official Documents (IDs, Passports)',
      'keys': 'Keys',
      'pets': 'Pets',
      'other': 'Other',
      'brownWallet': 'Brown Leather Wallet',
      'iphone13': 'iPhone 13',
      'nationalId': 'National ID Card',
      'carKeys': 'Car Keys with Keychain',
      'walletDescription':
          'Lost a brown leather wallet containing ID cards and bank cards. Please help.',
      'iphoneDescription':
          'Found an iPhone 13 in black in the university parking lot. Owner must provide proof of ownership.',
      'idCardDescription':
          'Lost my national ID card in the mall area. Will offer a reward to whoever finds it.',
      'keysDescription':
          'Lost my car keys with a blue keychain in the walkway area. Please help me find them.',
      'riyadhMall': 'Riyadh, King Fahd Commercial Complex',
      'jeddahUniversity': 'Jeddah, King Abdulaziz University',
      'dammamMall': 'Dammam, Dhahran Mall',
      'riyadhWalk': 'Riyadh, Al-Tahlia Walk',
      'similarItemFound': 'Similar Item Found',
      'similarItemFoundMessage':
          'Someone found an "iPhone" near the location you specified in your report.',
      'newMessage': 'New Message',
      'newMessageDetails':
          'Mohammed sent you a message regarding "Brown leather wallet".',
      'nearbyAlert': 'Nearby Alert',
      'nearbyAlertDetails':
          'There are 3 new lost item reports in your area in the last 24 hours.',
      'itemFound': 'Your Item Found',
      'itemFoundMessage':
          'Ahmed claims to have found the "Car Keys" you lost. Please check messages.',
      'reportPublished': 'Report published successfully!',
      'loginSuccess': 'Logged in successfully',
      'loginFailure': 'Login failed. Please check your credentials.',
      'signupSuccess': 'Account created successfully',
      'signupFailure': 'Registration failed. Please try again.',
      'messageSuccess': 'Message sent successfully',
      'messageFailure': 'Failed to send message',
      'requiredField': 'This field is required',
      'invalidEmail': 'Please enter a valid email',
      'passwordTooShort': 'Password must be at least 6 characters',
      'authRequired': 'Please login to use this feature',
      'loading': 'Loading...',
      'logout': 'Logout',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'deleteConfirmation': 'Are you sure you want to delete this?',
      'errorTitle': 'Error',
      'successTitle': 'Success',
      'tryAgain': 'Try Again',
      'markAsRead': 'Mark as Read',
      'markAllAsRead': 'Mark All as Read',
      'noNotifications': 'No notifications',
      'noMessages': 'No messages',
      'noConversations': 'No conversations yet',
      'startConversation': 'Start a conversation by contacting a report owner',
      'online': 'Online',
      'offline': 'Offline',
      'lastActive': 'Last active',
      'justNow': 'Just now',
      'minutesAgo': '{} minutes ago',
      'hoursAgo': '{} hours ago',
      'daysAgo': '{} days ago',
      'weeksAgo': '{} weeks ago',
      'signInWithGoogle': 'Sign in with Google',
      'signUpWithGoogle': 'Sign up with Google',
      'or': 'OR',
      'googleLoginError': 'Error signing in with Google',
      'googleLoginCancelled': 'Google sign in was cancelled',
      'reportDeleted': 'Report deleted successfully',
      'deleteError': 'Failed to delete report',
      'deleteConfirmation':
          'Are you sure you want to delete this report? This action cannot be undone.',
      'edit': 'Edit',
      'editReport': 'Edit Report',
      'updateReport': 'Update Report',
      'reportUpdated': 'Report updated successfully',
      'updateError': 'Failed to update report',
      'keepImage': 'Keep current image',
      'newConversation': 'New Conversation',
      'selectUser': 'Select a user to start a conversation with',
      'searchUsers': 'Search users...',
      'startChat': 'Start Chat',
      'createNewConversation': 'Create New Conversation',
      'directMessages': 'Direct Messages',
      'noUsersFound': 'No users found',
      'messageSent': 'Message sent successfully',
    },
    'ar': {
      'appTitle': 'مفقودات ومعثورات',
      'home': 'الرئيسية',
      'addReport': 'إضافة بلاغ',
      'search': 'بحث',
      'notifications': 'الإشعارات',
      'messages': 'الرسائل',
      'darkMode': 'الوضع الداكن',
      'language': 'English',
      'account': 'حسابي',
      'nearbyLostItems': 'مفقودات قريبة',
      'nearbyFoundItems': 'معثورات قريبة',
      'foundItems': 'تم إيجادها',
      'myReports': 'بلاغاتي',
      'recentReports': 'أحدث البلاغات',
      'viewAll': 'عرض الكل',
      'loadMore': 'عرض المزيد',
      'lost': 'مفقود',
      'found': 'معثور',
      'contact': 'تواصل',
      'viewDetails': 'عرض التفاصيل',
      'reportType': 'نوع البلاغ',
      'itemCategory': 'فئة الغرض',
      'itemTitle': 'عنوان الغرض',
      'itemDescription': 'وصف الغرض',
      'itemDate': 'التاريخ',
      'itemLocation': 'الموقع',
      'itemImage': 'صورة (اختياري)',
      'uploadImage': 'رفع صورة',
      'submitReport': 'نشر البلاغ',
      'searchPlaceholder': 'ابحث بالكلمات المفتاحية...',
      'allCategories': 'كل الفئات',
      'allTypes': 'الكل',
      'lostItems': 'مفقودات',
      'foundItems': 'معثورات',
      'noResults': 'لا توجد نتائج مطابقة',
      'selectConversation': 'اختر محادثة',
      'typeMessage': 'اكتب رسالتك هنا...',
      'login': 'تسجيل الدخول',
      'signup': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'forgotPassword': 'نسيت كلمة المرور؟',
      'fullName': 'الاسم الكامل',
      'phoneNumber': 'رقم الهاتف',
      'loginWith': 'أو سجل دخول بواسطة',
      'selectCategory': 'اختر الفئة',
      'browseFiles': 'استعرض الملفات',
      'electronics': 'إلكترونيات (هواتف، أجهزة)',
      'personal': 'أغراض شخصية (محافظ، حقائب)',
      'documents': 'وثائق رسمية (هويات، جوازات)',
      'keys': 'مفاتيح',
      'pets': 'حيوانات أليفة',
      'other': 'أخرى',
      'brownWallet': 'محفظة جلدية بنية',
      'iphone13': 'هاتف آيفون 13',
      'nationalId': 'بطاقة هوية وطنية',
      'carKeys': 'مفاتيح سيارة مع ميدالية',
      'walletDescription':
          'فقدت محفظة جلدية بنية تحتوي على أوراق هوية وبطاقات بنكية. الرجاء المساعدة.',
      'iphoneDescription':
          'عثرت على هاتف آيفون 13 لونه أسود في مواقف الجامعة. على صاحبه تقديم أدلة الملكية.',
      'idCardDescription':
          'فقدت بطاقة الهوية الوطنية الخاصة بي في منطقة المجمع التجاري. سأقدم مكافأة لمن يجدها.',
      'keysDescription':
          'فقدت مفاتيح سيارتي مع ميدالية زرقاء في منطقة الممشى. أرجو المساعدة في العثور عليها.',
      'riyadhMall': 'تعز شارع جمال القبة',
      'jeddahUniversity': 'جامعة الوطنيه ',
      'dammamMall': 'تعز ستي مول',
      'riyadhWalk': 'تعز جولة بير باشا',
      'similarItemFound': 'تم العثور على غرض مشابه',
      'similarItemFoundMessage':
          'شخص ما عثر على "هاتف آيفون" بالقرب من الموقع الذي حددته في بلاغك.',
      'newMessage': 'رسالة جديدة',
      'newMessageDetails': 'محمد أرسل لك رسالة بخصوص "محفظة جلدية بنية".',
      'nearbyAlert': 'تنبيه قريب',
      'nearbyAlertDetails':
          'هناك 3 بلاغات جديدة عن مفقودات في منطقتك خلال الـ 24 ساعة الماضية.',
      'itemFound': 'تم العثور على غرضك',
      'itemFoundMessage':
          'أحمد يدعي أنه عثر على "مفاتيح سيارة" التي فقدتها. يرجى مراجعة الرسائل.',
      'reportPublished': 'تم نشر البلاغ بنجاح!',
      'loginSuccess': 'تم تسجيل الدخول بنجاح',
      'loginFailure':
          'فشل تسجيل الدخول. يرجى التحقق من بيانات الاعتماد الخاصة بك.',
      'signupSuccess': 'تم إنشاء الحساب بنجاح',
      'signupFailure': 'فشل التسجيل. يرجى المحاولة مرة أخرى.',
      'messageSuccess': 'تم إرسال الرسالة بنجاح',
      'messageFailure': 'فشل إرسال الرسالة',
      'requiredField': 'هذا الحقل مطلوب',
      'invalidEmail': 'يرجى إدخال بريد إلكتروني صحيح',
      'passwordTooShort': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
      'authRequired': 'يرجى تسجيل الدخول لاستخدام هذه الميزة',
      'loading': 'جاري التحميل...',
      'logout': 'تسجيل الخروج',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'deleteConfirmation': 'هل أنت متأكد من رغبتك في الحذف؟',
      'errorTitle': 'خطأ',
      'successTitle': 'نجاح',
      'tryAgain': 'حاول مرة أخرى',
      'markAsRead': 'تعيين كمقروء',
      'markAllAsRead': 'تعيين الكل كمقروء',
      'noNotifications': 'لا توجد إشعارات',
      'noMessages': 'لا توجد رسائل',
      'noConversations': 'لا توجد محادثات بعد',
      'startConversation': 'ابدأ محادثة بالتواصل مع صاحب بلاغ',
      'online': 'متصل',
      'offline': 'غير متصل',
      'lastActive': 'آخر نشاط',
      'justNow': 'الآن',
      'minutesAgo': 'منذ {} دقائق',
      'hoursAgo': 'منذ {} ساعات',
      'daysAgo': 'منذ {} أيام',
      'weeksAgo': 'منذ {} أسابيع',
      'signInWithGoogle': 'تسجيل الدخول باستخدام جوجل',
      'signUpWithGoogle': 'التسجيل باستخدام جوجل',
      'or': 'أو',
      'googleLoginError': 'خطأ في تسجيل الدخول باستخدام جوجل',
      'googleLoginCancelled': 'تم إلغاء تسجيل الدخول باستخدام جوجل',
      'reportDeleted': 'تم حذف البلاغ بنجاح',
      'deleteError': 'فشل في حذف البلاغ',
      'deleteConfirmation':
          'هل أنت متأكد من رغبتك في حذف هذا البلاغ؟ لا يمكن التراجع عن هذا الإجراء.',
      'edit': 'تعديل',
      'editReport': 'تعديل البلاغ',
      'updateReport': 'تحديث البلاغ',
      'reportUpdated': 'تم تحديث البلاغ بنجاح',
      'updateError': 'فشل في تحديث البلاغ',
      'keepImage': 'الاحتفاظ بالصورة الحالية',
      'newConversation': 'محادثة جديدة',
      'selectUser': 'اختر مستخدمًا لبدء محادثة معه',
      'searchUsers': 'البحث عن مستخدمين...',
      'startChat': 'بدء المحادثة',
      'createNewConversation': 'إنشاء محادثة جديدة',
      'directMessages': 'رسائل مباشرة',
      'noUsersFound': 'لم يتم العثور على مستخدمين',
      'messageSent': 'تم إرسال الرسالة بنجاح',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// =============== الثيمات ===============

class AppThemes {
  static final primaryColor = Color(0xFF5D5CDE);
  static final secondaryColor = Color(0xFF6366F1);

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      buttonColor: primaryColor,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      background: Color(0xFF181818),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF202020),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    scaffoldBackgroundColor: Color(0xFF121212),
    cardTheme: CardTheme(
      color: Color(0xFF2D2D2D),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      buttonColor: primaryColor,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      backgroundColor: Color(0xFF202020),
    ),
  );
}

// =============== التطبيق الرئيسي ===============

class LostFoundApp extends StatefulWidget {
  @override
  _LostFoundAppState createState() => _LostFoundAppState();
}

class _LostFoundAppState extends State<LostFoundApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = Locale('ar', 'SA');

  final AppDataProvider _dataProvider = AppDataProvider();

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleLocale() {
    setState(() {
      _locale = _locale.languageCode == 'ar'
          ? Locale('en', 'US')
          : Locale('ar', 'SA');
    });
  }

  @override
  void initState() {
    super.initState();
    _dataProvider.initListeners();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مفقودات ومعثورات',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedBuilder(
        animation: _dataProvider,
        builder: (context, _) {
          return MainScreen(
            toggleTheme: _toggleTheme,
            toggleLocale: _toggleLocale,
            dataProvider: _dataProvider,
            locale: _locale,
          );
        },
      ),
    );
  }
}

// =============== الشاشة الرئيسية ===============

class MainScreen extends StatefulWidget {
  final Function toggleTheme;
  final Function toggleLocale;
  final AppDataProvider dataProvider;
  final Locale locale;

  const MainScreen({
    Key? key,
    required this.toggleTheme,
    required this.toggleLocale,
    required this.dataProvider,
    required this.locale,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // بيانات البحث
  List<Report> _filteredReports = [];
  ReportType? _selectedReportType;
  String _searchQuery = '';
  String? _selectedCategory;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredReports = widget.dataProvider.reports;
  }

  void _openLoginModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LoginDialog(
          dataProvider: widget.dataProvider,
        );
      },
    );
  }

  Future<void> _filterReports() async {
    final filteredReports = await widget.dataProvider.searchReports(
      _searchQuery.isNotEmpty ? _searchQuery : null,
      _selectedReportType,
      _selectedCategory,
    );

    setState(() {
      _filteredReports = filteredReports;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // مربع حوار تأكيد الحذف
  void _showDeleteConfirmation(BuildContext context, String reportId) {
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(loc.get('delete')),
          content: Text(loc.get('deleteConfirmation')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // إغلاق مربع الحوار
              },
              child: Text(loc.get('cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                // إغلاق مربع حوار التأكيد
                Navigator.pop(dialogContext);
                // إغلاق مربع حوار التفاصيل إذا كان مفتوحًا
                Navigator.of(context).pop();

                // حذف البلاغ
                final success =
                    await widget.dataProvider.deleteReport(reportId);

                if (success) {
                  _showSnackBar(loc.get('reportDeleted'));
                } else {
                  _showSnackBar(loc.get('deleteError'));
                }
              },
              child: Text(loc.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  // مربع حوار تعديل البلاغ
  void _showEditReportDialog(BuildContext context, Report report) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // متغيرات للنموذج
    final titleController = TextEditingController(text: report.title);
    final descriptionController =
        TextEditingController(text: report.description);
    final locationController = TextEditingController(text: report.location);

    ReportType reportType = report.type;
    String category = Report._getCategoryFromIcon(report.icon);
    DateTime selectedDate = report.date;
    File? selectedImage;
    bool keepExistingImage = report.imageUrl != null;

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.get('editReport'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // نوع البلاغ
                            Text(
                              loc.get('reportType'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        reportType = ReportType.lost;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: reportType == ReportType.lost
                                            ? Colors.amber.withOpacity(0.1)
                                            : theme.colorScheme.surface,
                                        border: Border.all(
                                          color: reportType == ReportType.lost
                                              ? Colors.amber
                                              : Colors.grey.shade300,
                                          width: reportType == ReportType.lost
                                              ? 2
                                              : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            loc.get('lost'),
                                            style: TextStyle(
                                              fontWeight:
                                                  reportType == ReportType.lost
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        reportType = ReportType.found;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: reportType == ReportType.found
                                            ? Colors.green.withOpacity(0.1)
                                            : theme.colorScheme.surface,
                                        border: Border.all(
                                          color: reportType == ReportType.found
                                              ? Colors.green
                                              : Colors.grey.shade300,
                                          width: reportType == ReportType.found
                                              ? 2
                                              : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.pan_tool,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            loc.get('found'),
                                            style: TextStyle(
                                              fontWeight:
                                                  reportType == ReportType.found
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // فئة الغرض
                            Text(
                              loc.get('itemCategory'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: category,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'electronics',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('electronics')),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'personal',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('personal')),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'documents',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('documents')),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'keys',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('keys')),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pets',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('pets')),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(loc.get('other')),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        category = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // عنوان الغرض
                            Text(
                              loc.get('itemTitle'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: titleController,
                              decoration: InputDecoration(
                                hintText: loc.get('brownWallet'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.get('requiredField');
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // وصف الغرض
                            Text(
                              loc.get('itemDescription'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.get('requiredField');
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // التاريخ
                            Text(
                              loc.get('itemDate'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now()
                                      .subtract(Duration(days: 365)),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && picked != selectedDate) {
                                  setState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                    ),
                                    Icon(Icons.calendar_today),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // الموقع
                            Text(
                              loc.get('itemLocation'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: locationController,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.get('requiredField');
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // صورة الغرض
                            Text(
                              loc.get('itemImage'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),

                            // خيار الاحتفاظ بالصورة الحالية
                            if (report.imageUrl != null)
                              Row(
                                children: [
                                  Checkbox(
                                    value: keepExistingImage,
                                    onChanged: (value) {
                                      setState(() {
                                        keepExistingImage = value ?? true;
                                      });
                                    },
                                  ),
                                  Text(loc.get('keepImage')),
                                ],
                              ),

                            // عرض الصورة الحالية أو الجديدة
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: selectedImage != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            selectedImage!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                  : keepExistingImage && report.imageUrl != null
                                      ? Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                report.imageUrl!,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        )
                                      : InkWell(
                                          onTap: () async {
                                            final pickedImage = await widget
                                                .dataProvider
                                                .pickImage();
                                            if (pickedImage != null) {
                                              setState(() {
                                                selectedImage = pickedImage;
                                              });
                                            }
                                          },
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.cloud_upload,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                loc.get('uploadImage'),
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              ),
                                              SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final pickedImage =
                                                      await widget.dataProvider
                                                          .pickImage();
                                                  if (pickedImage != null) {
                                                    setState(() {
                                                      selectedImage =
                                                          pickedImage;
                                                    });
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  foregroundColor:
                                                      Colors.black87,
                                                ),
                                                child: Text(
                                                    loc.get('browseFiles')),
                                              ),
                                            ],
                                          ),
                                        ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(loc.get('cancel')),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(dialogContext);

                              final success =
                                  await widget.dataProvider.updateReport(
                                report.id,
                                titleController.text,
                                descriptionController.text,
                                locationController.text,
                                selectedDate,
                                reportType,
                                category,
                                selectedImage,
                                keepExistingImage,
                              );

                              if (success) {
                                _showSnackBar(loc.get('reportUpdated'));
                              } else {
                                _showSnackBar(loc.get('updateError'));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(loc.get('updateReport')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تعديل اتجاه الواجهة بناءً على اللغة المحددة
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.get('appTitle')),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: loc.get('darkMode'),
              onPressed: () => widget.toggleTheme(),
            ),
            IconButton(
              icon: Text(
                loc.get('language'),
                style: TextStyle(fontSize: 14),
              ),
              onPressed: () => widget.toggleLocale(),
            ),
            IconButton(
              icon: widget.dataProvider.isLoggedIn
                  ? widget.dataProvider.userPhotoUrl != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              NetworkImage(widget.dataProvider.userPhotoUrl!),
                        )
                      : CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          child: Text(
                            widget.dataProvider.userName.isNotEmpty
                                ? widget.dataProvider.userName.substring(0, 1)
                                : '?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                  : Icon(Icons.account_circle),
              tooltip: loc.get('account'),
              onPressed: () {
                if (!widget.dataProvider.isLoggedIn) {
                  _openLoginModal();
                } else {
                  // عرض قائمة منسدلة لخيارات الحساب
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(loc.get('account')),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                widget.dataProvider.userPhotoUrl != null
                                    ? CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(
                                            widget.dataProvider.userPhotoUrl!),
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                        child: Text(
                                          widget.dataProvider.userName
                                                  .isNotEmpty
                                              ? widget.dataProvider.userName
                                                  .substring(0, 1)
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.dataProvider.userName,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        widget.dataProvider._firebaseService
                                                .currentUser?.email ??
                                            '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            TextButton.icon(
                              icon: Icon(Icons.logout),
                              label: Text(loc.get('logout')),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.dataProvider.signOut();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
        body: widget.dataProvider.isLoading
            ? Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _currentIndex,
                children: [
                  // الصفحة الرئيسية
                  _buildDashboardTab(context),

                  // صفحة إضافة بلاغ
                  _buildAddReportTab(context),

                  // صفحة البحث
                  _buildSearchTab(context),

                  // صفحة الإشعارات
                  _buildNotificationsTab(context),

                  // صفحة الرسائل
                  _buildMessagesTab(context),
                ],
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // إذا اختار المستخدم أي شيء غير الصفحة الرئيسية أو البحث وهو غير مسجل دخول
            if (index != 0 && index != 2 && !widget.dataProvider.isLoggedIn) {
              _openLoginModal();
              return;
            }

            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: loc.get('home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: loc.get('addReport'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: loc.get('search'),
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text(
                    widget.dataProvider.unreadNotificationsCount.toString()),
                isLabelVisible:
                    widget.dataProvider.unreadNotificationsCount > 0,
                child: Icon(Icons.notifications_outlined),
              ),
              activeIcon: Badge(
                label: Text(
                    widget.dataProvider.unreadNotificationsCount.toString()),
                isLabelVisible:
                    widget.dataProvider.unreadNotificationsCount > 0,
                child: Icon(Icons.notifications),
              ),
              label: loc.get('notifications'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              activeIcon: Icon(Icons.message),
              label: loc.get('messages'),
            ),
          ],
        ),
      ),
    );
  }

  // ============= بناء صفحة لوحة المعلومات =============
  Widget _buildDashboardTab(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // إحصائيات
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                icon: Icons.search,
                iconColor: Colors.amber,
                value: widget.dataProvider.lostReports.length.toString(),
                label: loc.get('nearbyLostItems'),
              ),
              _buildStatCard(
                icon: Icons.pan_tool,
                iconColor: Colors.green,
                value: widget.dataProvider.foundReports.length.toString(),
                label: loc.get('nearbyFoundItems'),
              ),
              _buildStatCard(
                icon: Icons.check_circle,
                iconColor: Colors.blue,
                value: '5',
                label: loc.get('foundItems'),
              ),
              _buildStatCard(
                icon: Icons.notifications_active,
                iconColor: Colors.purple,
                value: widget.dataProvider.notifications.length.toString(),
                label: loc.get('myReports'),
              ),
            ],
          ),

          SizedBox(height: 24),

          // أحدث البلاغات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.get('recentReports'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 2; // انتقل إلى صفحة البحث
                  });
                },
                child: Text(loc.get('viewAll')),
              ),
            ],
          ),

          SizedBox(height: 16),

          // قائمة البلاغات
          if (widget.dataProvider.reports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(loc.get('noResults')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: widget.dataProvider.reports.length,
              itemBuilder: (context, index) {
                final report = widget.dataProvider.reports[index];
                return _buildReportCard(context, report);
              },
            ),

          if (widget.dataProvider.reports.isNotEmpty) ...[
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 2; // انتقل إلى صفحة البحث
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(loc.get('loadMore')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: iconColor),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============= بناء كارت البلاغ =============
  Widget _buildReportCard(BuildContext context, Report report) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final formattedTimeAgo =
        MockDataService.formatTimeAgo(report.date, widget.locale);

    // التحقق مما إذا كان المستخدم الحالي هو مالك البلاغ
    bool isOwner = widget.dataProvider.isLoggedIn &&
        report.ownerId == widget.dataProvider._firebaseService.currentUserId;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة والنوع
          Stack(
            children: [
              report.imageUrl != null
                  ? Image.network(
                      report.imageUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 140,
                          width: double.infinity,
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            report.icon,
                            size: 60,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 140,
                      width: double.infinity,
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(
                        report.icon,
                        size: 60,
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: report.type == ReportType.lost
                        ? Colors.amber
                        : Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    report.type == ReportType.lost
                        ? loc.get('lost')
                        : loc.get('found'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // المحتوى
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان والتاريخ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        report.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formattedTimeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // الوصف
                Text(
                  report.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),

                // الموقع
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // الإجراءات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isOwner)
                      TextButton.icon(
                        onPressed: () async {
                          if (!widget.dataProvider.isLoggedIn) {
                            _openLoginModal();
                            return;
                          }

                          final result = await widget.dataProvider
                              .contactReportOwner(report);
                          if (result) {
                            setState(() {
                              _currentIndex = 4; // انتقل إلى صفحة الرسائل
                            });
                          } else {
                            _showSnackBar(loc.get('messageFailure'));
                          }
                        },
                        icon: Icon(Icons.chat_bubble_outline),
                        label: Text(loc.get('contact')),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    if (isOwner)
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _showEditReportDialog(context, report);
                            },
                            icon: Icon(Icons.edit_outlined,
                                color: theme.colorScheme.primary),
                            label: Text(loc.get('edit')),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showDeleteConfirmation(context, report.id);
                            },
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            label: Text(loc.get('delete')),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    TextButton.icon(
                      onPressed: () {
                        // عرض التفاصيل الكاملة للبلاغ
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(report.title),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (report.imageUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          report.imageUrl!,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    SizedBox(height: 16),
                                    Text(
                                      report.type == ReportType.lost
                                          ? loc.get('lost')
                                          : loc.get('found'),
                                      style: TextStyle(
                                        color: report.type == ReportType.lost
                                            ? Colors.amber
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(report.description),
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            report.location,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          formattedTimeAgo,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(loc.get('cancel')),
                                ),
                                if (widget.dataProvider.isLoggedIn && !isOwner)
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      final result = await widget.dataProvider
                                          .contactReportOwner(report);
                                      if (result) {
                                        setState(() {
                                          _currentIndex =
                                              4; // انتقل إلى صفحة الرسائل
                                        });
                                      } else {
                                        _showSnackBar(
                                            loc.get('messageFailure'));
                                      }
                                    },
                                    child: Text(loc.get('contact')),
                                  ),
                                if (isOwner) ...[
                                  TextButton.icon(
                                    icon: Icon(Icons.edit,
                                        color: theme.colorScheme.primary),
                                    label: Text(loc.get('edit'),
                                        style: TextStyle(
                                            color: theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showEditReportDialog(context, report);
                                    },
                                  ),
                                  TextButton.icon(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    label: Text(loc.get('delete'),
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      // عرض مربع حوار تأكيد قبل الحذف
                                      _showDeleteConfirmation(
                                          context, report.id);
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                      icon: Icon(Icons.visibility_outlined),
                      label: Text(loc.get('viewDetails')),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============= بناء صفحة إضافة بلاغ =============
  Widget _buildAddReportTab(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // متغيرات لنموذج إضافة البلاغ
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    ReportType reportType = ReportType.lost;
    String category = 'other';
    DateTime selectedDate = DateTime.now();
    File? selectedImage;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.get('addReport'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: StatefulBuilder(builder: (context, setState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نوع البلاغ
                      Text(
                        loc.get('reportType'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  reportType = ReportType.lost;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: reportType == ReportType.lost
                                      ? Colors.amber.withOpacity(0.1)
                                      : theme.colorScheme.surface,
                                  border: Border.all(
                                    color: reportType == ReportType.lost
                                        ? Colors.amber
                                        : Colors.grey.shade300,
                                    width:
                                        reportType == ReportType.lost ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      loc.get('lost'),
                                      style: TextStyle(
                                        fontWeight:
                                            reportType == ReportType.lost
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  reportType = ReportType.found;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: reportType == ReportType.found
                                      ? Colors.green.withOpacity(0.1)
                                      : theme.colorScheme.surface,
                                  border: Border.all(
                                    color: reportType == ReportType.found
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width:
                                        reportType == ReportType.found ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pan_tool,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      loc.get('found'),
                                      style: TextStyle(
                                        fontWeight:
                                            reportType == ReportType.found
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // فئة الغرض
                      Text(
                        loc.get('itemCategory'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(loc.get('selectCategory')),
                            ),
                            icon: Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(Icons.arrow_drop_down),
                            ),
                            value: category,
                            items: [
                              DropdownMenuItem(
                                value: 'electronics',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('electronics')),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'personal',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('personal')),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'documents',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('documents')),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'keys',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('keys')),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'pets',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('pets')),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(loc.get('other')),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  category = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // عنوان الغرض
                      Text(
                        loc.get('itemTitle'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: loc.get('brownWallet'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.get('requiredField');
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // وصف الغرض
                      Text(
                        loc.get('itemDescription'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: loc.get('walletDescription'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.get('requiredField');
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // التاريخ
                      Text(
                        loc.get('itemDate'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate:
                                DateTime.now().subtract(Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != selectedDate) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: TextStyle(fontSize: 16),
                              ),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // الموقع
                      Text(
                        loc.get('itemLocation'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: locationController,
                        decoration: InputDecoration(
                          hintText: loc.get('riyadhMall'),
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.get('requiredField');
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // صورة (اختياري)
                      Text(
                        loc.get('itemImage'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            // style: BorderStyle.dashed,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selectedImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      selectedImage!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : InkWell(
                                onTap: () async {
                                  final pickedImage =
                                      await widget.dataProvider.pickImage();
                                  if (pickedImage != null) {
                                    setState(() {
                                      selectedImage = pickedImage;
                                    });
                                  }
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      loc.get('uploadImage'),
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final pickedImage = await widget
                                            .dataProvider
                                            .pickImage();
                                        if (pickedImage != null) {
                                          setState(() {
                                            selectedImage = pickedImage;
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.black87,
                                      ),
                                      child: Text(loc.get('browseFiles')),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      SizedBox(height: 24),

                      // زر النشر
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final result =
                                  await widget.dataProvider.addReport(
                                titleController.text,
                                descriptionController.text,
                                locationController.text,
                                selectedDate,
                                reportType,
                                category,
                                selectedImage,
                              );

                              if (result) {
                                _showSnackBar(loc.get('reportPublished'));
                                setState(() {
                                  reportType = ReportType.lost;
                                  category = 'other';
                                  selectedDate = DateTime.now();
                                  selectedImage = null;
                                });
                                titleController.clear();
                                descriptionController.clear();
                                locationController.clear();

                                this.setState(() {
                                  _currentIndex =
                                      0; // العودة إلى الصفحة الرئيسية
                                });
                              } else {
                                _showSnackBar(loc.get('errorTitle'));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            loc.get('submitReport'),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============= بناء صفحة البحث =============
  Widget _buildSearchTab(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.get('search'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // مربع البحث
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: loc.get('searchPlaceholder'),
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      // تصفية الفئة
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedCategory,
                              hint: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(loc.get('allCategories')),
                              ),
                              icon: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.arrow_drop_down),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('allCategories')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'electronics',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('electronics')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'personal',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('personal')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'documents',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('documents')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'keys',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('keys')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'pets',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('pets')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('other')),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),

                      // تصفية النوع
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ReportType?>(
                              isExpanded: true,
                              value: _selectedReportType,
                              hint: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(loc.get('allTypes')),
                              ),
                              icon: Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.arrow_drop_down),
                              ),
                              items: [
                                DropdownMenuItem<ReportType?>(
                                  value: null,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('allTypes')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: ReportType.lost,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('lostItems')),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: ReportType.found,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(loc.get('foundItems')),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedReportType = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),

                      // زر البحث
                      ElevatedButton(
                        onPressed: _filterReports,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        child: Icon(Icons.search),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // نتائج البحث
          Expanded(
            child: _filteredReports.isEmpty
                ? Center(
                    child: Text(
                      loc.get('noResults'),
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) {
                      return _buildReportCard(context, _filteredReports[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============= بناء صفحة الإشعارات =============
  Widget _buildNotificationsTab(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.get('notifications'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (widget.dataProvider.notifications.isNotEmpty)
                TextButton(
                  onPressed: () {
                    widget.dataProvider.markAllNotificationsAsRead();
                  },
                  child: Text(loc.get('markAllAsRead')),
                ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: widget.dataProvider.notifications.isEmpty
                ? Center(
                    child: Text(
                      loc.get('noNotifications'),
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.dataProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          widget.dataProvider.notifications[index];
                      return _buildNotificationItem(context, notification);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, NotificationModel notification) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: notification.iconColor.withOpacity(0.2),
              child: Icon(
                notification.icon,
                color: notification.iconColor,
              ),
            ),
            if (!notification.read)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(notification.message),
            SizedBox(height: 4),
            Text(
              MockDataService.formatTimeAgo(
                  notification.timestamp, widget.locale),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          // تحديث حالة الإشعار إلى مقروء
          if (!notification.read) {
            widget.dataProvider.markNotificationAsRead(notification.id);
          }
        },
      ),
    );
  }

  // ============= بناء صفحة الرسائل =============
  Widget _buildMessagesTab(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // متغيرات للمحادثات
    final messageController = TextEditingController();
    final selectedConversationIndex = ValueNotifier<int?>(
        widget.dataProvider.conversations.isNotEmpty ? 0 : null);

    // إضافة حالة لإظهار واجهة إنشاء محادثة جديدة
    final showNewConversation = ValueNotifier<bool>(false);
    final searchUserController = TextEditingController();
    final filteredUsers =
        ValueNotifier<List<UserModel>>(widget.dataProvider.users);

    // تحديث قائمة المستخدمين المفلترة عند تغيير نص البحث
    void filterUsers(String query) {
      if (query.isEmpty) {
        filteredUsers.value = widget.dataProvider.users;
      } else {
        filteredUsers.value = widget.dataProvider.users
            .where((user) =>
                user.name.toLowerCase().contains(query.toLowerCase()) ||
                user.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.get('messages'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showNewConversation.value = true;
                  filterUsers('');
                },
                icon: Icon(Icons.add),
                label: Text(loc.get('newConversation')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // واجهة المحادثات
          ValueListenableBuilder<bool>(
            valueListenable: showNewConversation,
            builder: (context, showNewChat, _) {
              if (showNewChat) {
                // واجهة إنشاء محادثة جديدة
                return Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.get('createNewConversation'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () {
                                  showNewConversation.value = false;
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            loc.get('selectUser'),
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 12),

                          // مربع البحث عن المستخدمين
                          TextField(
                            controller: searchUserController,
                            decoration: InputDecoration(
                              hintText: loc.get('searchUsers'),
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: filterUsers,
                          ),
                          SizedBox(height: 16),

                          // قائمة المستخدمين
                          Expanded(
                            child: ValueListenableBuilder<List<UserModel>>(
                              valueListenable: filteredUsers,
                              builder: (context, users, _) {
                                if (users.isEmpty) {
                                  return Center(
                                    child: Text(
                                      loc.get('noUsersFound'),
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    return Card(
                                      margin: EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: theme
                                              .colorScheme.primary
                                              .withOpacity(0.2),
                                          backgroundImage: user.photoURL != null
                                              ? NetworkImage(user.photoURL!)
                                              : null,
                                          child: user.photoURL == null
                                              ? Text(
                                                  user.name.isNotEmpty
                                                      ? user.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        title: Text(user.name),
                                        subtitle: Text(user.email),
                                        trailing: ElevatedButton(
                                          onPressed: () async {
                                            final conversationId = await widget
                                                .dataProvider
                                                .createDirectConversation(
                                                    user.id);

                                            if (conversationId != null) {
                                              showNewConversation.value = false;

                                              // البحث عن المحادثة الجديدة في القائمة
                                              final conversationIndex = widget
                                                  .dataProvider.conversations
                                                  .indexWhere((conversation) =>
                                                      conversation.id ==
                                                      conversationId);

                                              if (conversationIndex >= 0) {
                                                selectedConversationIndex
                                                    .value = conversationIndex;
                                              }

                                              _showSnackBar(
                                                  loc.get('messageSent'));
                                            } else {
                                              _showSnackBar(
                                                  loc.get('messageFailure'));
                                            }
                                          },
                                          child: Text(loc.get('startChat')),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else if (widget.dataProvider.conversations.isEmpty) {
                // عرض رسالة عندما لا توجد محادثات
                return Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          loc.get('noConversations'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.get('startConversation'),
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            showNewConversation.value = true;
                            filterUsers('');
                          },
                          icon: Icon(Icons.add),
                          label: Text(loc.get('createNewConversation')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // عرض واجهة المحادثات العادية
                return Expanded(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: selectedConversationIndex,
                    builder: (context, selectedIndex, _) {
                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // قائمة المحادثات
                            Container(
                              width: MediaQuery.of(context).size.width * 0.35,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // مربع البحث
                                  Padding(
                                    padding: EdgeInsets.all(8),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: loc.get('search'),
                                        prefixIcon:
                                            Icon(Icons.search, size: 20),
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor:
                                            theme.colorScheme.surfaceVariant,
                                      ),
                                    ),
                                  ),

                                  Divider(height: 1),

                                  // قائمة المحادثات
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: widget
                                          .dataProvider.conversations.length,
                                      itemBuilder: (context, index) {
                                        final conversation = widget
                                            .dataProvider.conversations[index];
                                        final lastMessage =
                                            conversation.lastMessage;

                                        return ListTile(
                                          leading: Stack(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: theme
                                                    .colorScheme.primary
                                                    .withOpacity(0.2),
                                                child: Text(
                                                  conversation.userName
                                                      .substring(0, 1),
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              if (conversation.isOnline)
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: theme.cardColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          title: Text(
                                            conversation.userName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: lastMessage != null
                                              ? Text(
                                                  lastMessage.content,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                              : Text(loc.get('noMessages')),
                                          trailing: lastMessage != null
                                              ? Text(
                                                  MockDataService.formatTime(
                                                      lastMessage.timestamp),
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                )
                                              : null,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          selected: selectedIndex == index,
                                          selectedTileColor: theme
                                              .colorScheme.primary
                                              .withOpacity(0.1),
                                          onTap: () {
                                            selectedConversationIndex.value =
                                                index;
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // منطقة المحادثة
                            Expanded(
                              child: selectedIndex == null
                                  ? Center(
                                      child:
                                          Text(loc.get('selectConversation')),
                                    )
                                  : Column(
                                      children: [
                                        // رأس المحادثة
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: theme.dividerColor,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: theme
                                                        .colorScheme.primary
                                                        .withOpacity(0.2),
                                                    radius: 18,
                                                    child: Text(
                                                      widget
                                                          .dataProvider
                                                          .conversations[
                                                              selectedIndex]
                                                          .userName
                                                          .substring(0, 1),
                                                      style: TextStyle(
                                                        color: theme.colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                  if (widget
                                                      .dataProvider
                                                      .conversations[
                                                          selectedIndex]
                                                      .isOnline)
                                                    Positioned(
                                                      bottom: 0,
                                                      right: 0,
                                                      child: Container(
                                                        width: 10,
                                                        height: 10,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color:
                                                                theme.cardColor,
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    widget
                                                        .dataProvider
                                                        .conversations[
                                                            selectedIndex]
                                                        .userName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    widget
                                                            .dataProvider
                                                            .conversations[
                                                                selectedIndex]
                                                            .isOnline
                                                        ? loc.get('online')
                                                        : '${loc.get('lastActive')}: ${MockDataService.formatTimeAgo(widget.dataProvider.conversations[selectedIndex].lastActive, widget.locale)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Spacer(),
                                              IconButton(
                                                icon: Icon(Icons.more_vert),
                                                onPressed: () {},
                                              ),
                                            ],
                                          ),
                                        ),

                                        // الرسائل
                                        Expanded(
                                          child: Container(
                                            color: theme
                                                .colorScheme.surfaceVariant
                                                .withOpacity(0.3),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            child: widget
                                                    .dataProvider
                                                    .conversations[
                                                        selectedIndex]
                                                    .messages
                                                    .isEmpty
                                                ? Center(
                                                    child: Text(
                                                        loc.get('noMessages')),
                                                  )
                                                : ListView.builder(
                                                    itemCount: widget
                                                        .dataProvider
                                                        .conversations[
                                                            selectedIndex]
                                                        .messages
                                                        .length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final message = widget
                                                          .dataProvider
                                                          .conversations[
                                                              selectedIndex]
                                                          .messages[index];
                                                      final isMe =
                                                          message.senderId ==
                                                              widget
                                                                  .dataProvider
                                                                  .currentUser
                                                                  ?.uid;

                                                      return Align(
                                                        alignment: isMe
                                                            ? Alignment
                                                                .centerRight
                                                            : Alignment
                                                                .centerLeft,
                                                        child: Container(
                                                          margin:
                                                              EdgeInsets.only(
                                                            top: 8,
                                                            bottom: 8,
                                                            left: isMe ? 64 : 0,
                                                            right:
                                                                isMe ? 0 : 64,
                                                          ),
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal: 16,
                                                            vertical: 10,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isMe
                                                                ? theme
                                                                    .colorScheme
                                                                    .primary
                                                                : theme
                                                                    .cardColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                message.content,
                                                                style:
                                                                    TextStyle(
                                                                  color: isMe
                                                                      ? Colors
                                                                          .white
                                                                      : theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 4),
                                                              Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    MockDataService
                                                                        .formatTime(
                                                                            message.timestamp),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: isMe
                                                                          ? Colors
                                                                              .white70
                                                                          : Colors
                                                                              .grey,
                                                                    ),
                                                                  ),
                                                                  if (isMe) ...[
                                                                    SizedBox(
                                                                        width:
                                                                            4),
                                                                    Icon(
                                                                      message.read
                                                                          ? Icons
                                                                              .done_all
                                                                          : Icons
                                                                              .done,
                                                                      size: 12,
                                                                      color: Colors
                                                                          .white70,
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ),

                                        // مربع نص الرسالة
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: theme.cardColor,
                                            border: Border(
                                              top: BorderSide(
                                                color: theme.dividerColor,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.attach_file),
                                                onPressed: () {},
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller: messageController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        loc.get('typeMessage'),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    filled: true,
                                                    fillColor: theme.colorScheme
                                                        .surfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              InkWell(
                                                onTap: () async {
                                                  if (messageController.text
                                                      .trim()
                                                      .isNotEmpty) {
                                                    final conversationId =
                                                        widget
                                                            .dataProvider
                                                            .conversations[
                                                                selectedIndex]
                                                            .id;
                                                    final result = await widget
                                                        .dataProvider
                                                        .sendMessage(
                                                      conversationId,
                                                      messageController.text
                                                          .trim(),
                                                    );

                                                    if (result) {
                                                      messageController.clear();
                                                    } else {
                                                      _showSnackBar(loc.get(
                                                          'messageFailure'));
                                                    }
                                                  }
                                                },
                                                child: CircleAvatar(
                                                  backgroundColor:
                                                      theme.colorScheme.primary,
                                                  child: const Icon(
                                                    Icons.send,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// =============== مربع حوار تسجيل الدخول ===============
class LoginDialog extends StatefulWidget {
  final AppDataProvider dataProvider;

  const LoginDialog({
    Key? key,
    required this.dataProvider,
  }) : super(key: key);

  @override
  _LoginDialogState createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isLogin ? loc.get('login') : loc.get('signup'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),

                      // Tab switching
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isLogin = true;
                                  _errorMessage = null;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _isLogin
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  loc.get('login'),
                                  style: TextStyle(
                                    fontWeight: _isLogin
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _isLogin
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isLogin = false;
                                  _errorMessage = null;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: !_isLogin
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  loc.get('signup'),
                                  style: TextStyle(
                                    fontWeight: !_isLogin
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: !_isLogin
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Show error message if there is one
                      if (_errorMessage != null) ...[
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                      ],

                      // Google Sign In Button (available in both login and signup modes)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGoogleLoading
                              ? null
                              : () async {
                                  setState(() {
                                    _isGoogleLoading = true;
                                    _errorMessage = null;
                                  });

                                  try {
                                    final success = await widget.dataProvider
                                        .signInWithGoogle();

                                    if (success) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(loc.get('loginSuccess')),
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        _errorMessage = loc.get('loginFailure');
                                      });
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _errorMessage = e.toString();
                                    });
                                  } finally {
                                    setState(() {
                                      _isGoogleLoading = false;
                                    });
                                  }
                                },
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  height: 10,
                                  width: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(Icons.login,
                                  size: 20, color: Colors.black),
                          label: Text(_isLogin
                              ? loc.get('signInWithGoogle')
                              : loc.get('signUpWithGoogle')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // OR divider
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              loc.get('or'),
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Login form
                      if (_isLogin) ...[
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: loc.get('email'),
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: loc.get('password'),
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: isRTL
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: Text(loc.get('forgotPassword')),
                          ),
                        ),
                        SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    // التحقق من صحة البيانات
                                    if (_emailController.text.isEmpty ||
                                        _passwordController.text.isEmpty) {
                                      setState(() {
                                        _errorMessage =
                                            loc.get('requiredField');
                                      });
                                      return;
                                    }

                                    setState(() {
                                      _isSubmitting = true;
                                      _errorMessage = null;
                                    });

                                    try {
                                      final success =
                                          await widget.dataProvider.signIn(
                                        _emailController.text,
                                        _passwordController.text,
                                      );

                                      if (success) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(loc.get('loginSuccess')),
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      } else {
                                        setState(() {
                                          _errorMessage =
                                              loc.get('loginFailure');
                                        });
                                      }
                                    } catch (e) {
                                      setState(() {
                                        _errorMessage = e.toString();
                                      });
                                    } finally {
                                      setState(() {
                                        _isSubmitting = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(loc.get('login')),
                          ),
                        ),
                      ],

                      // Signup form
                      if (!_isLogin) ...[
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: loc.get('fullName'),
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: loc.get('email'),
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: loc.get('phoneNumber'),
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: loc.get('password'),
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    // التحقق من صحة البيانات
                                    if (_nameController.text.isEmpty ||
                                        _emailController.text.isEmpty ||
                                        _phoneController.text.isEmpty ||
                                        _passwordController.text.isEmpty) {
                                      setState(() {
                                        _errorMessage =
                                            loc.get('requiredField');
                                      });
                                      return;
                                    }

                                    if (_passwordController.text.length < 6) {
                                      setState(() {
                                        _errorMessage =
                                            loc.get('passwordTooShort');
                                      });
                                      return;
                                    }

                                    setState(() {
                                      _isSubmitting = true;
                                      _errorMessage = null;
                                    });

                                    try {
                                      final success =
                                          await widget.dataProvider.signUp(
                                        _emailController.text,
                                        _passwordController.text,
                                        _nameController.text,
                                        _phoneController.text,
                                      );

                                      if (success) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(loc.get('signupSuccess')),
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      } else {
                                        setState(() {
                                          _errorMessage =
                                              loc.get('signupFailure');
                                        });
                                      }
                                    } catch (e) {
                                      setState(() {
                                        _errorMessage = e.toString();
                                      });
                                    } finally {
                                      setState(() {
                                        _isSubmitting = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(loc.get('signup')),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============== خدمة البيانات الوهمية للعرض ===============

class MockDataService {
  static String formatTimeAgo(DateTime dateTime, Locale locale) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final language = locale.languageCode;

    if (difference.inDays > 7) {
      // Just show the date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return language == 'ar'
          ? 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : (difference.inDays == 2 ? 'يومين' : 'أيام')}'
          : '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return language == 'ar'
          ? 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : (difference.inHours == 2 ? 'ساعتين' : 'ساعات')}'
          : '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return language == 'ar'
          ? 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : (difference.inMinutes == 2 ? 'دقيقتين' : 'دقائق')}'
          : '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return language == 'ar' ? 'الآن' : 'Just now';
    }
  }

  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}




