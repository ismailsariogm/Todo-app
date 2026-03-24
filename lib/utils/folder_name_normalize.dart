/// Klasör adlarını "aynı isim" kontrolü için normalize eder:
/// büyük/küçük harf, ı/i, u/ü, o/ö eşlemesi, noktalama ve boşluklar kaldırılır.
String normalizeFolderNameForDuplicate(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.toLowerCase();
  // Türkçe büyük harf kalıntıları
  s = s.replaceAll('İ', 'i').replaceAll('I', 'ı');
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    buf.write(_foldChar(ch));
  }
  s = buf.toString();
  // Yalnızca harf ve rakam (noktalama ve boşluk yok)
  return s.replaceAll(RegExp(r'[^a-z0-9ğüşıöç]+'), '');
}

String _foldChar(String ch) {
  switch (ch) {
    case 'ı':
    case 'i':
    case 'î':
    case 'ï':
      return 'i';
    case 'ü':
    case 'u':
    case 'û':
      return 'u';
    case 'ö':
    case 'o':
    case 'ô':
      return 'o';
    case 'ş':
      return 's';
    case 'ğ':
      return 'g';
    case 'ç':
      return 'c';
    default:
      return ch;
  }
}
