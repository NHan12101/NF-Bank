/// Utility functions for formatting names in the app
String removeVietnameseAccents(String str) {
  var result = str.trim();
  const vietnameseMap = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'A': 'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'èéẻẽẹêềếểễệ',
    'E': 'ÈÉẺẼẸÊỀẾỂỄỆ',
    'i': 'ìíỉĩị',
    'I': 'ÌÍỈĨỊ',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'O': 'ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ',
    'u': 'ùúủũụưừứửữự',
    'U': 'ÙÚỦŨỤƯỪỨỬỮỰ',
    'y': 'ỳýỷỹỵ',
    'Y': 'ỲÝỶỸỴ',
  };

  for (var entry in vietnameseMap.entries) {
    final replaceChar = entry.key;
    for (var i = 0; i < entry.value.length; i++) {
      result = result.replaceAll(entry.value[i], replaceChar);
    }
  }

  return result.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}
