import 'dart:convert';

import 'package:http/http.dart' as http;

import '../rpc/rpc.dart' as rpc;

const String chainlinkLatestRoundDataSelector = '0xfeaf968c';

/// Polygon mainnet Chainlink USD feeds used by Polymarket crypto dashboards.
const Map<String, String> polygonChainlinkUsdFeeds = <String, String>{
  'BTC': '0xc907E116054Ad103354f2D350FD2514433D57F6f',
  'ETH': '0xF9680D99D6C9589e2a93a78A04A279e509205945',
  'SOL': '0x10C8264C0935b3B9870013e057f330Ff3e9C56dC',
  'XRP': '0x785ba89291f676b5386652eB12b30cF361020694',
  'BNB': '0x82a6c4AF830caa6c97bb504425f6A992D0824C07',
  'DOGE': '0xbaf9327b6564454F4a3364C33eFeEf032b4b4444',
  'MATIC': '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0',
};

final class ChainlinkFeedPrice {
  const ChainlinkFeedPrice({
    required this.asset,
    required this.priceUsd,
    required this.updatedAt,
    this.errorCode,
  });

  ChainlinkFeedPrice.error(this.asset, this.errorCode)
    : priceUsd = 0,
      updatedAt = DateTime.utc(1970);

  final String asset;
  final double priceUsd;
  final DateTime updatedAt;
  final String? errorCode;

  bool get hasError => errorCode != null;
}

final class ChainlinkFeedSnapshot {
  const ChainlinkFeedSnapshot({required this.prices, this.errorCode});

  ChainlinkFeedSnapshot.error(this.errorCode) : prices = const [];

  final List<ChainlinkFeedPrice> prices;
  final String? errorCode;

  bool get hasError => errorCode != null;
}

/// Minimal read-only Chainlink AggregatorV3 client over Polygon JSON-RPC.
final class ChainlinkPriceFeedClient {
  ChainlinkPriceFeedClient({
    http.Client? httpClient,
    String rpcUrl = rpc.polygonRpc,
    Map<String, String> feeds = polygonChainlinkUsdFeeds,
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _rpcUrl = rpcUrl.trim().isEmpty ? rpc.polygonRpc : rpcUrl.trim(),
       _feeds = feeds.map(
         (asset, address) => MapEntry(asset.toUpperCase(), address),
       );

  final http.Client _http;
  final bool _ownsClient;
  final String _rpcUrl;
  final Map<String, String> _feeds;

  void close() {
    if (_ownsClient) {
      _http.close();
    }
  }

  Future<ChainlinkFeedSnapshot> snapshot(List<String> assets) async {
    final results = await Future.wait(assets.map(price), eagerError: false);
    return ChainlinkFeedSnapshot(prices: results);
  }

  Future<ChainlinkFeedPrice> price(String asset) async {
    final upper = asset.toUpperCase();
    final feed = _feeds[upper];
    if (feed == null) {
      return ChainlinkFeedPrice.error(upper, 'unsupported_asset');
    }

    try {
      final response = await _http.post(
        Uri.parse(_rpcUrl),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, Object>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_call',
          'params': <Object>[
            <String, String>{
              'to': feed,
              'input': chainlinkLatestRoundDataSelector,
            },
            'latest',
          ],
        }),
      );
      if (response.statusCode < 200 || response.statusCode > 299) {
        return ChainlinkFeedPrice.error(
          upper,
          'rpc_http_${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return ChainlinkFeedPrice.error(upper, 'invalid_rpc_response');
      }
      if (body['error'] != null) {
        return ChainlinkFeedPrice.error(upper, 'rpc_error');
      }
      final result = body['result'];
      if (result is! String || result.length < 2) {
        return ChainlinkFeedPrice.error(upper, 'empty_result');
      }
      return decodeLatestRoundData(upper, result);
    } catch (e) {
      return ChainlinkFeedPrice.error(upper, 'exception:$e');
    }
  }
}

ChainlinkFeedPrice decodeLatestRoundData(String asset, String hex) {
  final data = hex.startsWith('0x') ? hex.substring(2) : hex;
  if (data.length < 320) {
    return ChainlinkFeedPrice.error(asset, 'response_too_short');
  }

  final answerHex = data.substring(64, 128);
  var answer = BigInt.parse(answerHex, radix: 16);
  if (answer >= (BigInt.one << 255)) {
    answer -= BigInt.one << 256;
  }

  final updatedAtSecs = BigInt.parse(
    data.substring(192, 256),
    radix: 16,
  ).toInt();
  return ChainlinkFeedPrice(
    asset: asset,
    priceUsd: answer.toDouble() / 1e8,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      updatedAtSecs * 1000,
      isUtc: true,
    ),
  );
}
