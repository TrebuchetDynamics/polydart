import 'package:polydart/src/relayer/approvals.dart';
import 'package:test/test.dart';

import '../support/relayer_calldata.dart';

void main() {
  group('buildAdapterApprovalCalls', () {
    final calls = buildAdapterApprovalCalls();

    test('returns exactly four calls — pUSD + CTF for each V2 adapter', () {
      expect(calls, hasLength(4));
    });

    test('spender ordering is [CTF collateral adapter, NegRisk adapter]', () {
      final spenders = <String>[
        ctfCollateralAdapter,
        negRiskCtfCollateralAdapter,
      ];
      for (var i = 0; i < spenders.length; i++) {
        final approveCall = calls[i * 2];
        final ctfCall = calls[i * 2 + 1];
        final spenderHex = encodedAddressWord(spenders[i]);
        expect(approveCall.target.toLowerCase(), pusdAddress.toLowerCase());
        expect(ctfCall.target.toLowerCase(), ctfAddress.toLowerCase());
        expect(approveCall.data.toLowerCase().contains(spenderHex), isTrue);
        expect(ctfCall.data.toLowerCase().contains(spenderHex), isTrue);
      }
    });
  });

  group('buildApprovalCalls', () {
    final calls = buildApprovalCalls();

    test('returns exactly six calls — pUSD + CTF for each V2 spender', () {
      expect(calls, hasLength(6));
    });

    test('alternates pUSD-approve / CTF-setApprovalForAll for each spender', () {
      // Even indices = pUSD ERC-20 approve (target=pUSD, selector 0x095ea7b3)
      // Odd  indices = CTF ERC-1155 setApprovalForAll (target=CTF, selector 0xa22cb465)
      for (var i = 0; i < calls.length; i++) {
        final c = calls[i];
        expect(c.value, '0');
        expect(c.data.startsWith('0x'), isTrue);
        if (i.isEven) {
          expect(
            c.target.toLowerCase(),
            pusdAddress.toLowerCase(),
            reason: 'index $i should target pUSD',
          );
          expect(c.data.substring(2, 10), '095ea7b3');
        } else {
          expect(
            c.target.toLowerCase(),
            ctfAddress.toLowerCase(),
            reason: 'index $i should target CTF',
          );
          expect(c.data.substring(2, 10), 'a22cb465');
        }
      }
    });

    test('spender ordering is [CTF V2, NegRisk V2, NegRisk Adapter]', () {
      final spenders = <String>[
        ctfExchangeV2,
        negRiskExchangeV2,
        negRiskAdapterV2,
      ];
      for (var i = 0; i < spenders.length; i++) {
        // Each spender appears twice (pUSD approve + CTF setApprovalForAll).
        // Both calls embed the spender right-padded into the calldata.
        final approveCall = calls[i * 2];
        final ctfCall = calls[i * 2 + 1];
        final spenderHex = encodedAddressWord(spenders[i]);
        expect(
          approveCall.data.toLowerCase().contains(spenderHex),
          isTrue,
          reason:
              'pUSD approve at index ${i * 2} should reference ${spenders[i]}',
        );
        expect(
          ctfCall.data.toLowerCase().contains(spenderHex),
          isTrue,
          reason:
              'CTF setApprovalForAll at index ${i * 2 + 1} should reference ${spenders[i]}',
        );
      }
    });

    test('approval data ends with maxUint256 / "true" tail', () {
      final maxUint =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      final boolTrue =
          '0000000000000000000000000000000000000000000000000000000000000001';
      for (var i = 0; i < calls.length; i++) {
        if (i.isEven) {
          expect(calls[i].data.toLowerCase().endsWith(maxUint), isTrue);
        } else {
          expect(calls[i].data.toLowerCase().endsWith(boolTrue), isTrue);
        }
      }
    });
  });
}
