import 'dart:math';

/// An endless deck that draws items in shuffled order.
///
/// Every item is drawn once before the deck reshuffles, so repeats only
/// happen after the whole deck has been seen. The first card after a
/// reshuffle is never the same as the last card drawn.
class RandomDeck<T> {
  RandomDeck(Iterable<T> items, {Random? random})
      : _items = List.unmodifiable(items),
        _random = random ?? Random() {
    if (_items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
  }

  final List<T> _items;
  final Random _random;
  final List<T> _queue = [];
  T? _last;

  int get length => _items.length;

  /// Draws the next item, reshuffling when the deck runs out.
  T next() {
    if (_queue.isEmpty) _refill();
    final item = _queue.removeLast();
    _last = item;
    return item;
  }

  /// Draws [count] distinct items (or all items if there are fewer).
  /// Does not affect the endless [next] sequence.
  List<T> sample(int count) {
    final shuffled = [..._items]..shuffle(_random);
    return shuffled.take(min(count, shuffled.length)).toList();
  }

  void _refill() {
    _queue
      ..addAll(_items)
      ..shuffle(_random);
    // `next` draws from the end; avoid repeating the previous card.
    if (_queue.length > 1 && _queue.last == _last) {
      final swapWith = _random.nextInt(_queue.length - 1);
      final tmp = _queue[swapWith];
      _queue[swapWith] = _queue.last;
      _queue[_queue.length - 1] = tmp;
    }
  }
}
