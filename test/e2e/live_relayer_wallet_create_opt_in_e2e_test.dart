import 'dart:io';
import 'dart:math';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _enableVar = 'POLYDART_LIVE_RELAYER_WALLET_CREATE';
const _ackVar = 'POLYDART_LIVE_RELAYER_WALLET_CREATE_ACK';
const _ackValue = 'I_UNDERSTAND_THIS_CAN_DEPLOY_A_POLYMARKET_SMART_WALLET';
const _alreadyExistsVar = 'POLYDART_LIVE_RELAYER_REPEAT_CREATE';
const _privateKeyVar = 'POLYDART_LIVE_PRIVATE_KEY';
const _randomKeyVar = 'POLYDART_LIVE_RANDOM_PRIVATE_KEY';
const _rpcUrlVar = 'POLYDART_LIVE_RPC_URL';

void main() {
  test(
    'LIVE opt-in: controlled private-key EOA can create or observe a Polymarket smart wallet via relayer WALLET-CREATE',
    () async {
      final privateKey = _privateKeyFromEnvironment();
      final signer = LocalEoaSigner(privateKeyHex: privateKey, chainId: 137);
      final owner = signer.address;
      final depositWallet = deriveDepositWallet(owner);
      final rpcUrl = Platform.environment[_rpcUrlVar]!;

      stdout.writeln('live_wallet_create.owner=$owner');
      stdout.writeln('live_wallet_create.expectedDepositWallet=$depositWallet');

      final session = SIWESession(signer: signer);
      addTearDown(session.close);
      await session.login();
      expect(session.hasSession, isTrue);

      final apiKey = await mintV2APIKey(session: session);
      expect(apiKey.key.trim(), isNotEmpty);
      expect(apiKey.address.toLowerCase(), owner.toLowerCase());

      final relayer = RelayerClient.v2(apiKey: apiKey);
      addTearDown(relayer.close);

      final beforeRelayer = await relayer.isDeployed(ownerAddress: owner);
      stdout.writeln(
        'live_wallet_create.before.relayerDeployed=${beforeRelayer.deployed} address=${beforeRelayer.address}',
      );
      final beforeCode = await hasCode(depositWallet, rpcUrl: rpcUrl);
      stdout.writeln('live_wallet_create.before.onchainCode=$beforeCode');

      if (beforeCode) {
        stdout.writeln(
          'live_wallet_create.state=already_deployed; skipping WALLET-CREATE by default',
        );
        if (Platform.environment[_alreadyExistsVar] == '1') {
          await _observeAlreadyExistingWalletCreate(
            relayer,
            owner,
            depositWallet,
          );
        } else {
          stdout.writeln(
            'live_wallet_create.repeatCreateSkipped=set $_alreadyExistsVar=1 to observe already-existing-wallet behavior',
          );
        }
        return;
      }

      final create = await relayer.submitWalletCreate(ownerAddress: owner);
      stdout.writeln(
        'live_wallet_create.create.transactionId=${create.transactionId} state=${create.state} proxy=${create.proxyAddress}',
      );
      expect(create.transactionId, isNotEmpty);
      expect(create.type, anyOf('', 'WALLET-CREATE'));
      if (create.proxyAddress.isNotEmpty) {
        expect(create.proxyAddress.toLowerCase(), depositWallet.toLowerCase());
      }

      final mined = await relayer.pollTransaction(
        txId: create.transactionId,
        maxAttempts: _intEnv('POLYDART_LIVE_RELAYER_POLL_ATTEMPTS', 90),
        interval: Duration(
          seconds: _intEnv('POLYDART_LIVE_RELAYER_POLL_SECONDS', 2),
        ),
      );
      stdout.writeln(
        'live_wallet_create.mined.transactionId=${mined.transactionId} state=${mined.state} proxy=${mined.proxyAddress}',
      );
      expect(mined.parsedState.isSuccess, isTrue);

      final codeDeployed = await _waitForOnChainCode(depositWallet, rpcUrl);
      stdout.writeln('live_wallet_create.after.onchainCode=$codeDeployed');
      expect(codeDeployed, isTrue);

      final afterRelayer = await relayer.isDeployed(ownerAddress: owner);
      stdout.writeln(
        'live_wallet_create.after.relayerDeployed=${afterRelayer.deployed} address=${afterRelayer.address}',
      );
      if (afterRelayer.address.isNotEmpty) {
        expect(afterRelayer.address.toLowerCase(), depositWallet.toLowerCase());
      }

      if (Platform.environment[_alreadyExistsVar] == '1') {
        await _observeAlreadyExistingWalletCreate(
          relayer,
          owner,
          depositWallet,
        );
      } else {
        stdout.writeln(
          'live_wallet_create.repeatCreateSkipped=set $_alreadyExistsVar=1 to observe already-existing-wallet behavior after code exists',
        );
      }
    },
    skip: _liveSkipReason(),
    timeout: Timeout(
      Duration(minutes: _intEnv('POLYDART_LIVE_TIMEOUT_MINUTES', 5)),
    ),
  );
}

Future<bool> _waitForOnChainCode(String depositWallet, String rpcUrl) async {
  final attempts = _intEnv('POLYDART_LIVE_DEPLOYED_POLL_ATTEMPTS', 45);
  final interval = Duration(
    seconds: _intEnv('POLYDART_LIVE_DEPLOYED_POLL_SECONDS', 2),
  );
  for (var i = 0; i < attempts; i++) {
    final deployed = await hasCode(depositWallet, rpcUrl: rpcUrl);
    stdout.writeln('live_wallet_create.codePoll.attempt=$i deployed=$deployed');
    if (deployed) return true;
    await Future<void>.delayed(interval);
  }
  return false;
}

Future<void> _observeAlreadyExistingWalletCreate(
  RelayerClient relayer,
  String owner,
  String depositWallet,
) async {
  try {
    final repeat = await relayer.submitWalletCreate(ownerAddress: owner);
    stdout.writeln(
      'live_wallet_create.repeat.accepted transactionId=${repeat.transactionId} state=${repeat.state} proxy=${repeat.proxyAddress}',
    );
    expect(repeat.transactionId, isNotEmpty);
    if (repeat.proxyAddress.isNotEmpty) {
      expect(repeat.proxyAddress.toLowerCase(), depositWallet.toLowerCase());
    }
  } catch (error) {
    final message = error.toString().toLowerCase();
    stdout.writeln('live_wallet_create.repeat.rejected $error');
    expect(
      message,
      anyOf(
        contains('already'),
        contains('exist'),
        contains('deploy'),
        contains('wallet'),
      ),
    );
  }
}

String? _liveSkipReason() {
  if (Platform.environment[_enableVar] != '1') {
    return 'set $_enableVar=1 to run live Polymarket relayer WALLET-CREATE';
  }
  if (Platform.environment[_ackVar] != _ackValue) {
    return 'set $_ackVar=$_ackValue to acknowledge live smart-wallet deployment risk';
  }
  if ((Platform.environment[_rpcUrlVar] ?? '').trim().isEmpty) {
    return 'set $_rpcUrlVar to a reliable Polygon RPC URL for on-chain code checks';
  }
  if ((Platform.environment[_privateKeyVar] ?? '').trim().isEmpty &&
      Platform.environment[_randomKeyVar] != '1') {
    return 'set $_privateKeyVar for a controlled live wallet, or $_randomKeyVar=1 to generate a new private key and risk a new WALLET-CREATE';
  }
  return null;
}

String _privateKeyFromEnvironment() {
  final configured = (Platform.environment[_privateKeyVar] ?? '').trim();
  if (configured.isNotEmpty) return configured;
  if (Platform.environment[_randomKeyVar] == '1') return _randomPrivateKeyHex();
  throw StateError('live private key not configured');
}

int _intEnv(String name, int fallback) {
  final parsed = int.tryParse(Platform.environment[name] ?? '');
  return parsed == null || parsed <= 0 ? fallback : parsed;
}

String _randomPrivateKeyHex() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  // Keep the scalar definitely below the secp256k1 order while still random.
  bytes[0] = 1 + random.nextInt(0x7f);
  return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}
