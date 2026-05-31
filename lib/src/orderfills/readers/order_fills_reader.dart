/// Reader contracts for orderfills backends.
library;

import '../models/models.dart';

abstract interface class OrderFillsReader {
  Future<List<OrderFill>> orderFilled(OrderFillsQuery query);
}

abstract interface class OrderFillsBlockNumberReader {
  Future<int> latestBlockNumber();
}
