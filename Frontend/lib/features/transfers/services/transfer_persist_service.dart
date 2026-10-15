import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedRecipient {
  const SavedRecipient({
    required this.accountNumber,
    required this.accountName,
    required this.nickname,
  });

  final String accountNumber;
  final String accountName;
  final String nickname;

  factory SavedRecipient.fromJson(Map<String, dynamic> json) => SavedRecipient(
        accountNumber: json['account_number']?.toString() ?? '',
        accountName: json['account_name']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'account_number': accountNumber,
        'account_name': accountName,
        'nickname': nickname,
      };
}

class TransferTemplate {
  const TransferTemplate({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.description,
  });

  final String id;
  final String name;
  final String accountNumber;
  final String accountName;
  final int amount;
  final String description;

  factory TransferTemplate.fromJson(Map<String, dynamic> json) => TransferTemplate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        accountName: json['account_name']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        description: json['description']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'account_number': accountNumber,
        'account_name': accountName,
        'amount': amount,
        'description': description,
      };
}

class TransferPersistService {
  const TransferPersistService();

  static const _recipientsKey = 'SAVED_RECIPIENTS';
  static const _templatesKey = 'TRANSFER_TEMPLATES';

  // --- Saved Recipients (Contacts) ---

  Future<List<SavedRecipient>> getSavedRecipients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_recipientsKey);
      if (data == null || data.isEmpty) return const [];
      final List decoded = jsonDecode(data);
      return decoded
          .map((item) => SavedRecipient.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveRecipient(SavedRecipient recipient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getSavedRecipients();
      
      final updatedList = list.where(
        (item) => item.accountNumber != recipient.accountNumber,
      ).toList();
      
      updatedList.add(recipient);
      
      final data = jsonEncode(updatedList.map((item) => item.toJson()).toList());
      await prefs.setString(_recipientsKey, data);
    } catch (e) {
      throw Exception('Không thể lưu danh bạ: $e');
    }
  }

  Future<void> deleteRecipient(String accountNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getSavedRecipients();
      final updatedList = list.where(
        (item) => item.accountNumber != accountNumber,
      ).toList();
      final data = jsonEncode(updatedList.map((item) => item.toJson()).toList());
      await prefs.setString(_recipientsKey, data);
    } catch (e) {
      throw Exception('Không thể xóa danh bạ: $e');
    }
  }

  // --- Transfer Templates ---

  Future<List<TransferTemplate>> getTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_templatesKey);
      if (data == null || data.isEmpty) return const [];
      final List decoded = jsonDecode(data);
      return decoded
          .map((item) => TransferTemplate.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTemplate(TransferTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getTemplates();
      
      final updatedList = list.where(
        (item) => item.id != template.id,
      ).toList();
      
      updatedList.add(template);
      
      final data = jsonEncode(updatedList.map((item) => item.toJson()).toList());
      await prefs.setString(_templatesKey, data);
    } catch (e) {
      throw Exception('Không thể lưu mẫu chuyển tiền: $e');
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getTemplates();
      final updatedList = list.where((item) => item.id != id).toList();
      final data = jsonEncode(updatedList.map((item) => item.toJson()).toList());
      await prefs.setString(_templatesKey, data);
    } catch (e) {
      throw Exception('Không thể xóa mẫu chuyển tiền: $e');
    }
  }
}
