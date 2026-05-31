part of 'orderresults.dart';

final class _RowIdentity {
  const _RowIdentity._(this._value);

  final String _value;

  static _RowIdentity from(String market, String tokenId) {
    final normalizedToken = _normalizeIdentityComponent(tokenId);
    if (normalizedToken.isNotEmpty) {
      return _RowIdentity._('token:$normalizedToken');
    }

    final normalizedMarket = _normalizeIdentityComponent(market);
    if (normalizedMarket.isNotEmpty) {
      return _RowIdentity._('market:$normalizedMarket');
    }

    return const _RowIdentity._('unknown');
  }

  @override
  String toString() => _value;
}

String _rowKey(String market, String tokenId) =>
    _RowIdentity.from(market, tokenId).toString();

String _normalizeIdentityComponent(String value) => value.trim().toLowerCase();
