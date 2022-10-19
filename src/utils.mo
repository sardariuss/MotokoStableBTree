import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import List "mo:base/List";
import Debug "mo:base/Debug";
import Order "mo:base/Order";
import Iter "mo:base/Iter";

module {

  // For convenience: from base module
  type Buffer<T> = Buffer.Buffer<T>;
  type Order = Order.Order;
  type Iter<T> = Iter.Iter<T>;
  type Result<K, V> = Result.Result<K, V>;

  /// Creates a buffer from an array
  public func toBuffer<T>(x :[T]) : Buffer<T>{
    let thisBuffer = Buffer.Buffer<T>(x.size());
    for(thisItem in x.vals()){
      thisBuffer.add(thisItem);
    };
    return thisBuffer;
  };

  /// Append two arrays using a buffer
  public func append<T>(left: [T], right: [T]) : [T] {
    let buffer = Buffer.Buffer<T>(left.size());
    for(val in left.vals()){
      buffer.add(val);
    };
    for(val in right.vals()){
      buffer.add(val);
    };
    return buffer.toArray();
  };

  /// Splits the buffers into two at the given index.
  /// The right buffer contains the element at the given index
  /// similarly to the Rust's vec::split_off method
  public func splitOff<T>(idx: Nat, buffer: Buffer<T>) : Buffer<T>{
    var tail = List.nil<T>();
    while(buffer.size() > idx){
      switch(buffer.removeLast()){
        case(null) { assert(false); };
        case(?last){
          tail := List.push<T>(last, tail);
        };
      };
    };
    toBuffer<T>(List.toArray(List.reverse<T>(tail)));
  };

  /// Insert an element into the buffer at given index
  public func insert<T>(idx: Nat, elem: T, buffer: Buffer<T>) {
    let tail = splitOff(idx, buffer);
    buffer.add(elem);
    buffer.append(tail);
  };

  /// Remove an element from the buffer at the given index
  /// Traps if index is out of bounds.
  public func remove<T>(idx: Nat, buffer: Buffer<T>) : T {
    let tail = splitOff(idx + 1, buffer);
    switch(tail.removeLast()){
      case(null) { Debug.trap("Index is out of bounds."); };
      case(?elem) {
        buffer.append(tail);
        elem;
      };
    };
  };

  /// Searches the element in the ordered array.
  public func binarySearch<T>(array: [T], order: (T, T) -> Order, elem: T) : Result<Nat, Nat> {
    search(array, order, elem, 0, array.size());
  };

  /// Searches recursively the element in the ordered array.
  func search<T>(array: [T], order: (T, T) -> Order, elem: T, idx: Nat, window: Nat) : Result<Nat, Nat> {
    if (window == 0) {
      return #err(idx);
    };
    let half_window = window / 2;
    let mid_idx = idx + half_window;
    let middle_elem = array[mid_idx];
    switch(order(middle_elem, elem)){
      case(#less)    { search(array, order, elem, mid_idx, half_window); };
      case(#greater) { search(array, order, elem, idx,     half_window); };
      case(#equal)   {                   #ok(mid_idx);                   };
    };
  };

  /// Similar as Rust's lexicographical-comparison.
  /// Two sequences are compared element by element.
  /// The first mismatching element defines which sequence is lexicographically less or greater than the other.
  /// If one sequence is a prefix of another, the shorter sequence is lexicographically less than the other.
  /// If two sequence have equivalent elements and are of the same length, then the sequences are lexicographically equal.
  /// An empty sequence is lexicographically less than any non-empty sequence.
  /// Two empty sequences are lexicographically equal.
  public func compare<T>(left: [T], right: [T], order: (T, T) -> Order) : Order {
    let left_size = left.size();
    let right_size = right.size();
    var idx : Nat = 0;
    // Iterate on left array
    while (idx < left_size){
      // If so far the array were equal, but right is shorter than left
      // it means it is a prefix of left, so left is greater.
      if (idx >= right_size){
        return #greater;
      };
      switch(order(left[idx], right[idx])){
        case(#less) { return #less; };
        case(#greater) { return #greater; };
        case(_) {}; // Continue iterating.
      };
    };
    // If we arrive here, it means at least left is contained in right
    if (left.size() == right_size){
      return #equal;
    };
    // Left is a prefix of right, so left is lesser.
    return #less;
  };

  /// Check if the array starts with the given prefix.
  public func startsWith<T>(array: [T], prefix: [T], order: (T, T) -> Order) : Bool {
    let prefix_size = prefix.size();
    // If the prefix is bigger, return false
    if (prefix_size > array.size()) {
      return false;
    };
    var idx : Nat = 0;
    // Iterate on the prefix
    while (idx < prefix_size){
      switch(order(array[idx], prefix[idx])){
        case(#equal) {}; // Values are equal, continue iterating.
        case(_) { return false; }; // Values are not equal, the array does not start with the prefix.
      };
    };
    // The array starts with the prefix.
    return true;
  };

  /// Check if the array is sorted in increasing order.
  public func isSortedInIncreasingOrder<T>(array: [T], order: (T, T) -> Order) : Bool {
    let array_size = array.size();
    var idx : Nat = 0;
    // Iterate on the array
    while (idx < (array_size - 1)){
      switch(order(array[idx], array[idx + 1])){
        case(#greater) { 
          // Previous is greater than next, wrong order
          return false;
        };
        case(_) {}; // Previous is less or equal than next, continue iterating
      };
    };
    // All elements have been checked one to one, the array is sorted.
    return true;
  };

};