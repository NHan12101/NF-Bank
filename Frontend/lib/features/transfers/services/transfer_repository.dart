import '../../../core/constants/api_url.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/utils/idempotency.dart' as idempotency;
import '../models/account_resolution.dart';
import '../models/transfer_receipt.dart';

class TransferRepository {
  const TransferRepository();

  Future<AccountResolution> resolveAccount(String accountNumber) async {
    final result = await ApiService.get(
      ApiUrl.resolveAccount(accountNumber),
      auth: true,
    );
    return AccountResolution.fromJson(_map(result.data));
  }

  Future<TransferReceipt> transfer({
    required String accountNumber,
    required int amount,
    required String description,
    required String idempotencyKey,
    required String transactionPin,
  }) async {
    final result = await ApiService.post(
      ApiUrl.transfer,
      auth: true,
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'receiver_account_number': accountNumber,
        'amount': amount,
        'description': description,
        'transaction_pin': transactionPin,
      },
    );
    return TransferReceipt.fromJson(_map(result.data));
  }

  Future<bool> hasTransactionPin() async {
    final result = await ApiService.get(
      ApiUrl.transactionPinStatus,
      auth: true,
    );
    return _map(result.data)['has_pin'] == true;
  }

  Future<void> setupTransactionPin(String pin, String confirmPin) async {
    await ApiService.post(
      ApiUrl.setupTransactionPin,
      auth: true,
      body: {'pin': pin, 'confirm_pin': confirmPin},
    );
  }

  Future<void> verifyTransactionPin(String pin, {bool isNewDevice = false}) async {
    await ApiService.post(
      ApiUrl.verifyTransactionPin,
      auth: true,
      body: {
        'pin': pin,
        'is_new_device': isNewDevice,
      },
    );
  }

  Future<Map<String, dynamic>> getMyStaticQR({String? tokenOverride}) async {
    final token = tokenOverride ?? await TokenStorage.getToken();
    final result = await ApiService.get(
      ApiUrl.qr,
      auth: true,
      headers: token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null,
    );
    return _map(result.data);
  }

  Future<Map<String, dynamic>> generateDynamicQR(int amount, String description) async {
    final result = await ApiService.post(
      ApiUrl.qr,
      auth: true,
      body: {
        'amount': amount,
        'description': description,
      },
    );
    return _map(result.data);
  }

  static String createIdempotencyKey() {
    return idempotency.createIdempotencyKey();
  }

  Future<TransferReceipt> withdraw({
    required String bankAccountNumber,
    required String accountHolderName,
    required String bankName,
    required int amount,
    required String transactionPin,
    required String identityCardLast4,
    required String idempotencyKey,
    String description = '',
  }) async {
    final result = await ApiService.post(
      ApiUrl.withdraw,
      auth: true,
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'bank_account_number': bankAccountNumber,
        'account_holder_name': accountHolderName,
        'bank_name': bankName,
        'amount': amount,
        'transaction_pin': transactionPin,
        'identity_card_last4': identityCardLast4,
        'description': description,
      },
    );
    return TransferReceipt.fromJson(_map(result.data));
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}
