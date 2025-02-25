import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:isar/src/common/isar_common.dart';
import 'package:isar/src/native/bindings.dart';
import 'package:isar/src/native/isar_core.dart';

/// @nodoc
class Txn extends Transaction {
  /// @nodoc
  Txn.sync(this.ptr, bool write) : super(true, write);

  /// @nodoc
  Txn.async(this.ptr, bool write, Stream<void> stream) : super(false, write) {
    _completers = Queue();
    stream.listen(
      (_) => _completers.removeFirst().complete(),
      onError: (Object e) => _completers.removeFirst().completeError(e),
    );
  }

  /// An arena allocator that has the same lifetime as this transaction.
  final alloc = Arena(malloc);

  /// The pointer to the native transaction.
  final Pointer<CIsarTxn> ptr;
  Pointer<CObject>? _cObjPtr;
  Pointer<CObjectSet>? _cObjSetPtr;

  late Pointer<Uint8> _buffer;
  int _bufferLen = -1;

  late final Queue<Completer<void>> _completers;

  /// Get a shared CObject pointer
  Pointer<CObject> getCObject() {
    _cObjPtr ??= alloc<CObject>();
    return _cObjPtr!;
  }

  /// Get a shared CObjectSet pointer
  Pointer<CObjectSet> getCObjectsSet() {
    _cObjSetPtr ??= alloc();
    return _cObjSetPtr!;
  }

  /// Allocate a new CObjectSet with the given capacity.
  Pointer<CObjectSet> newCObjectSet(int length) {
    final cObjSetPtr = alloc<CObjectSet>();
    cObjSetPtr.ref
      ..objects = alloc<CObject>(length)
      ..length = length;
    return cObjSetPtr;
  }

  /// Get a shared buffer with at least the specified size.
  Pointer<Uint8> getBuffer(int size) {
    if (_bufferLen < size) {
      final allocSize = (size * 1.3).toInt();
      _buffer = alloc(allocSize);
      _bufferLen = allocSize;
    }
    return _buffer;
  }

  /// Wait for the latest async operation to complete.
  Future<void> wait() {
    final completer = Completer<void>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<void> commit() {
    IC.isar_txn_finish(ptr, true);
    return wait();
  }

  @override
  void commitSync() {
    nCall(IC.isar_txn_finish(ptr, true));
  }

  @override
  Future<void> abort() {
    IC.isar_txn_finish(ptr, false);
    return wait();
  }

  @override
  void abortSync() {
    nCall(IC.isar_txn_finish(ptr, false));
  }

  @override
  void free() {
    alloc.releaseAll();
  }
}
