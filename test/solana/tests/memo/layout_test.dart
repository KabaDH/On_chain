import 'package:test/test.dart';
import 'package:on_chain/solana/solana.dart';

void main() {
  group('Memo layout', () {
    _roundTrip();
    _byteLevel();
    _nonAscii();
    _empty();
    _jsonConsistency();
  });
}

void _roundTrip() {
  test('round-trip preserves hex-looking memos', () {
    const memos = [
      '1234',
      'DEAD',
      'DEADBEEF',
      'cafe',
      '0xabcd',
      '0XABCD',
      'Hello, Solana!',
      'https://example.com/path?a=1&b=2',
      'mixedCase123',
    ];
    for (final memo in memos) {
      final encoded = MemoLayout(memo: memo).toBytes();
      final decoded = MemoLayout.fromBuffer(encoded);
      expect(decoded.memo, memo,
          reason: 'fromBuffer(toBytes(x)) must equal x for "$memo"');
    }
  });
}

void _byteLevel() {
  test('encodes hex-looking memo as UTF-8 bytes, not raw hex', () {
    // "1234" must be the four ASCII code points, not [0x12, 0x34].
    expect(MemoLayout(memo: '1234').toBytes(), [0x31, 0x32, 0x33, 0x34]);
    // "DEAD" must be the ASCII bytes, not [0xDE, 0xAD].
    expect(MemoLayout(memo: 'DEAD').toBytes(), [0x44, 0x45, 0x41, 0x44]);
  });
}

void _nonAscii() {
  test('encodes multi-byte characters as UTF-8 and round-trips', () {
    // 'é' (U+00E9) must be the two-byte UTF-8 sequence, proving UTF-8 (not
    // Latin-1/ASCII) is used.
    expect(MemoLayout(memo: 'é').toBytes(), [0xC3, 0xA9]);
    const memos = ['привет 🚀', 'café', '日本語'];
    for (final memo in memos) {
      final decoded = MemoLayout.fromBuffer(MemoLayout(memo: memo).toBytes());
      expect(decoded.memo, memo);
    }
  });
}

void _empty() {
  test('handles an empty memo', () {
    expect(MemoLayout(memo: '').toBytes(), <int>[]);
    expect(MemoLayout.fromBuffer(<int>[]).memo, '');
  });
}

void _jsonConsistency() {
  test('toJson agrees with the encoded bytes', () {
    const memo = 'DEADBEEF';
    final layout = MemoLayout(memo: memo);
    expect(layout.toJson(), {'memo': memo});
    expect(MemoLayout.fromBuffer(layout.toBytes()).memo, memo);
  });
}
