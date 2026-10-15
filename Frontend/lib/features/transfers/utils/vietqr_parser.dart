class VietQRParser {
  VietQRParser._();

  /// Phân tích chuỗi mã QR nhận được từ camera hoặc dán văn bản.
  /// Hỗ trợ cả hai chuẩn:
  /// 1. Chuẩn VietQR (EMVCo - bắt đầu bằng 000201)
  /// 2. Chuẩn nội bộ NF Bank: `nfbank://transfer?account=...&amount=...&desc=...`
  static Map<String, String>? parse(String qrCode) {
    qrCode = qrCode.trim();

    // 1. Kiểm tra chuẩn nội bộ NF Bank
    if (qrCode.startsWith('nfbank://')) {
      try {
        final uri = Uri.parse(qrCode);
        if (uri.host == 'transfer') {
          final account = uri.queryParameters['account'] ?? '';
          final amountStr = uri.queryParameters['amount'] ?? '';
          final description = uri.queryParameters['desc'] ?? '';
          final amount = int.tryParse(amountStr) ?? 0;
          return {
            'type': 'TRANSFER',
            'account': account,
            'bin': '970499', // BIN mặc định của NF Bank
            'amount': amount > 0 ? amount.toString() : '',
            'description': description,
          };
        } else if (uri.host == 'payment') {
          final token = uri.queryParameters['token'] ?? '';
          return {
            'type': 'PAYMENT',
            'token': token,
          };
        }
      } catch (_) {
        // Tiếp tục thử phân tích theo định dạng khác
      }
    }

    // 2. Kiểm tra định dạng VietQR (EMVCo)
    if (!qrCode.startsWith('000201')) {
      return null;
    }

    String account = '';
    String bin = '';
    String amount = '';
    String description = '';

    try {
      int i = 0;
      while (i < qrCode.length) {
        if (i + 4 > qrCode.length) break;
        String tag = qrCode.substring(i, i + 2);
        int len = int.tryParse(qrCode.substring(i + 2, i + 4)) ?? 0;
        i += 4;
        if (i + len > qrCode.length) break;
        String val = qrCode.substring(i, i + len);
        i += len;

        if (tag == '38') {
          // Phân tích Sub-tags của Tag 38
          int j = 0;
          while (j < val.length) {
            if (j + 4 > val.length) break;
            String subTag = val.substring(j, j + 2);
            int subLen = int.tryParse(val.substring(j + 2, j + 4)) ?? 0;
            j += 4;
            if (j + subLen > val.length) break;
            String subVal = val.substring(j, j + subLen);
            j += subLen;

            if (subTag == '01') {
              // Phân tích Sub-sub-tags của Sub-tag 01 (Thông tin thụ hưởng)
              int k = 0;
              while (k < subVal.length) {
                if (k + 4 > subVal.length) break;
                String subSubTag = subVal.substring(k, k + 2);
                int subSubLen = int.tryParse(subVal.substring(k + 2, k + 4)) ?? 0;
                k += 4;
                if (k + subSubLen > subVal.length) break;
                String subSubVal = subVal.substring(k, k + subSubLen);
                k += subSubLen;

                if (subSubTag == '00') {
                  bin = subSubVal; // Mã BIN Ngân hàng
                } else if (subSubTag == '01') {
                  account = subSubVal; // Số tài khoản thụ hưởng
                }
              }
            }
          }
        } else if (tag == '54') {
          amount = val; // Số tiền giao dịch (Dynamic QR)
        } else if (tag == '62') {
          // Phân tích Sub-tags của Tag 62
          int j = 0;
          while (j < val.length) {
            if (j + 4 > val.length) break;
            String subTag = val.substring(j, j + 2);
            int subLen = int.tryParse(val.substring(j + 2, j + 4)) ?? 0;
            j += 4;
            if (j + subLen > val.length) break;
            String subVal = val.substring(j, j + subLen);
            j += subLen;
            if (subTag == '08') {
              description = subVal; // Nội dung giao dịch
            }
          }
        }
      }
    } catch (_) {
      // Phục hồi và trả về dữ liệu parse được tốt nhất
    }

    if (account.isEmpty) {
      return null;
    }

    return {
      'type': 'TRANSFER',
      'account': account,
      'bin': bin,
      'amount': amount,
      'description': description,
    };
  }
}
