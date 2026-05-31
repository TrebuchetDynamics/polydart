/// Read-only on-chain OrderFilled truth models and readers.
///
/// Mirrors Polygolem `pkg/orderfills` public model, validation, and Polygon
/// JSON-RPC reader surface.
library;

export 'orderfills_core.dart';
export 'readers/rpc_orderfills_reader.dart';
