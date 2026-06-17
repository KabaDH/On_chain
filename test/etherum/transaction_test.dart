import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain/ethereum/ethereum.dart';
import 'package:test/test.dart';

void main() {
  /// transaction with leading zero s bytes.
  test('transaction leading zero s', () {
    final addr = ETHAddress('0x084937B3f86ea7BbCA86F2809809A65ED8A7ADa9');
    final signer = ETHSigner.fromKeyBytes(
      BytesUtils.fromHexString(
        'e9f4fe38ffc54abd156dd4b8a39611fce696af62841ee6422ee36ba7b26c53f5',
      ),
    );

    final receiver = ETHAddress('0x4fAfB33f0e492FD10e91b55ED88872104fFd94ee');
    final transaction = ETHTransaction(
      nonce: 0,
      from: addr,
      type: ETHTransactionType.legacy,
      to: receiver,
      gasLimit: BigInt.from(21000),
      data: const [],
      value: ETHHelper.toWei('0.01'),
      chainId: BigInt.from(97),
      gasPrice: BigInt.from(5000000000),
    );
    final serialize = transaction.serialized;
    final sign = signer.signConst(serialize);
    final signedSerialize = transaction.signedSerialized(sign);

    final decode = ETHTransaction.fromSerialized(signedSerialize);
    expect(decode.signedSerialized(), signedSerialize);
  });

  /// A zero-valued BigInt field must be RLP-encoded as the canonical empty byte
  /// string, not a non-canonical single 0x00 byte. Otherwise nodes reject the tx
  /// with "rlp: non-canonical integer (leading zero bytes)".
  test('bigintToBytes encodes zero as canonical empty bytes', () {
    expect(ETHTransactionUtils.bigintToBytes(BigInt.zero), <int>[]);
    // sanity: non-zero values are unaffected.
    expect(ETHTransactionUtils.bigintToBytes(BigInt.one), [0x01]);
    expect(ETHTransactionUtils.bigintToBytes(BigInt.from(0x2673c00)), [
      0x02,
      0x67,
      0x3c,
      0x00,
    ]);
  });

  /// Reproduces the Arbitrum failure: an EIP-1559 transaction with
  /// maxPriorityFeePerGas == 0 (the norm on L2s). The zero tip (GasTipCap) must
  /// serialize as an empty RLP item, not 0x00.
  test('EIP-1559 zero maxPriorityFeePerGas serializes canonically', () {
    final transaction = ETHTransaction(
      nonce: 17,
      from: ETHAddress('0xb90630D3108A368b5a7603A854bF24D6c9376d01'),
      type: ETHTransactionType.eip1559,
      to: ETHAddress('0x618d99A2F3412A2185246614D30bE233011Ee250'),
      gasLimit: BigInt.from(26606),
      data: const [],
      value: ETHHelper.toWei('0.01'),
      chainId: BigInt.from(421614), // Arbitrum Sepolia
      maxPriorityFeePerGas: BigInt.zero,
      maxFeePerGas: BigInt.from(40320000),
    );

    final serialized = transaction.serialized;
    // strip the EIP-1559 type prefix (0x02) before RLP-decoding the payload.
    expect(serialized.first, ETHTransactionType.eip1559.prefix);
    final fields = RLPDecoder.decode(serialized.sublist(1));

    // field[2] is maxPriorityFeePerGas (GasTipCap): must be empty, not [0].
    expect(fields[2], <int>[]);

    // round-trip still holds.
    final decode = ETHTransaction.fromSerialized(serialized);
    expect(decode.serialized, serialized);
    expect(decode.maxPriorityFeePerGas, BigInt.zero);
  });
}
