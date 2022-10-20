import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import List "mo:base/List";
import Debug "mo:base/Debug";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Int "mo:base/Int";

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
  public func splitOff<T>(buffer: Buffer<T>, idx: Nat) : Buffer<T>{
    var tail = List.nil<T>();
    while(buffer.size() > idx){
      switch(buffer.removeLast()){
        case(null) { assert(false); };
        case(?last){
          tail := List.push<T>(last, tail);
        };
      };
    };
    toBuffer<T>(List.toArray(tail));
  };

  /// Insert an element into the buffer at given index
  public func insert<T>(buffer: Buffer<T>, idx: Nat, elem: T) {
    let tail = splitOff(buffer, idx);
    buffer.add(elem);
    buffer.append(tail);
  };

  /// Remove an element from the buffer at the given index
  /// Traps if index is out of bounds.
  public func remove<T>(buffer: Buffer<T>, idx: Nat) : T {
    let tail = splitOff(buffer, idx + 1);
    switch(buffer.removeLast()){
      case(null) { Debug.trap("Index is out of bounds."); };
      case(?elem) {
        buffer.append(tail);
        elem;
      };
    };
  };

  /// Searches the element in the ordered array.
  public func binarySearch<T>(array: [T], order: (T, T) -> Order, elem: T) : Result<Nat, Nat> {
    // Return index 0 if array is empty
    if (array.size() == 0){
      return #err(0);
    };
    // Initialize search from first to last index
    var left : Nat = 0;
    var right : Int = array.size() - 1; // Right can become less than 0, hence the integer type
    // Search the array
    while (left < right) {
      let middle = Int.abs(left + (right - left) / 2);
      switch(order(elem, array[middle])){
        // If the element is present at the middle itself
        case(#equal) { return #ok(middle); };
        // If element is greater than mid, it can only be present in left subarray
        case(#greater) { left := middle + 1; };
        // If element is smaller than mid, it can only be present in right subarray
        case(#less) { right := middle - 1; };
      };
    };
    // The search did not find a match
    switch(order(elem, array[left])){
      case(#equal) { return #ok(left); };
      case(#greater) { return #err(left + 1); };
      case(#less) { return #err(left); };
    };
  };

  /// Similar as Rust's lexicographical-comparison.
  /// Two sequences are compared element by element.
  /// The first mismatching element defines which sequence is lexicographically less or greater than the other.
  /// If one sequence is a prefix of another, the shorter sequence is lexicographically less than the other.
  /// If two sequence have equivalent elements and are of the same length, then the sequences are lexicographically equal.
  /// An empty sequence is lexicographically less than any non-empty sequence.
  /// Two empty sequences are lexicographically equal.
  public func lexicographicallyCompare<T>(left: [T], right: [T], order: (T, T) -> Order) : Order {
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
      idx += 1;
    };
    // If we arrive here, it means at least left is contained in right
    if (left_size == right_size){
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
      idx += 1;
    };
    // The array starts with the prefix.
    return true;
  };

  /// Check if the array is sorted in increasing order.
  public func isSortedInIncreasingOrder<T>(array: [T], order: (T, T) -> Order) : Bool {
    let size_array = array.size();
    var idx : Nat = 0;
    // Iterate on the array
    while (idx + 1 < size_array){
      switch(order(array[idx], array[idx + 1])){
        case(#greater) { 
          // Previous is greater than next, wrong order
          return false;
        };
        case(_) {}; // Previous is less or equal than next, continue iterating
      };
      idx += 1;
    };
    // All elements have been checked one to one, the array is sorted.
    return true;
  };

};