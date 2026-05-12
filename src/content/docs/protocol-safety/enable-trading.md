---
title: Enable Trading Planning
description: Build wallet-mediated Enable Trading typed data and approval call plans without submitting live writes.
sidebar:
  order: 2
---

Enable Trading is a planning flow in Polydart. The SDK builds the CLOB auth typed data and deposit-wallet approval batch payloads that your app can present through a wallet. It does not hide raw keys, and this guide does not submit live transactions.

## Build The Approval Call Plan

`buildEnableTradingApprovalCalls()` returns the two approval calls required by the observed wallet UI flow. Validate the plan before displaying or signing it.

```dart
import 'package:polydart/polydart.dart';

List<DepositWalletCall> buildApprovalPlan() {
  final calls = buildEnableTradingApprovalCalls();
  validateEnableTradingApprovalCalls(calls);
  return calls;
}
```

The call plan is deterministic and constrained to the expected pUSD and USDC.e approvals.

## Build CLOB Auth Typed Data

The CLOB auth payload proves control of the EOA. The wallet signs it; Polydart does not store the wallet key.

```dart
import 'package:polydart/polydart.dart';

Map<String, dynamic> buildClobAuthPayload(WalletSigner signer) {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  return buildEnableTradingClobAuthTypedData(
    address: signer.address,
    timestamp: timestamp,
    nonce: 0,
    chainId: signer.chainId,
  );
}
```

## Build Deposit-Wallet Batch Typed Data

Use the deposit-wallet address, wallet nonce, deadline, and validated calls to build the batch payload. Your app decides how it obtains the nonce and how it submits any signed relay request.

```dart
import 'package:polydart/polydart.dart';

Map<String, dynamic> buildApprovalBatchPayload({
  required String depositWallet,
  required String nonce,
  required String deadline,
}) {
  final calls = buildEnableTradingApprovalCalls();
  validateEnableTradingApprovalCalls(calls);

  return buildEnableTradingApprovalBatchTypedData(
    depositWallet: depositWallet,
    nonce: nonce,
    deadline: deadline,
    calls: calls,
  );
}
```

## Request Wallet Signatures

When the user confirms in their wallet, the helper returns hex signatures. Keep submission, retry, and relay credential handling in an explicitly gated application path.

```dart
import 'package:polydart/polydart.dart';

Future<({String clobAuth, String approvalBatch})> signEnableTradingPlan({
  required WalletSigner signer,
  required String depositWallet,
  required String nonce,
  required String deadline,
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final calls = buildEnableTradingApprovalCalls();

  final clobAuth = await signEnableTradingClobAuthTypedData(
    signer: signer,
    timestamp: timestamp,
    nonce: 0,
  );

  final approvalBatch = await signEnableTradingApprovalBatchTypedData(
    signer: signer,
    depositWallet: depositWallet,
    nonce: nonce,
    deadline: deadline,
    calls: calls,
  );

  return (clobAuth: clobAuth, approvalBatch: approvalBatch);
}
```

## What This Does Not Do

This planning flow does not:

- Submit approvals.
- Place orders.
- Store wallet keys.
- Bypass live gates.
- Infer user consent from configuration alone.

Use [live safety gates](/protocol-safety/live-safety-gates/) before any application-owned live submission path.
