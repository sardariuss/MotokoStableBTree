import Types "types";
import Node "node";

import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Stack "mo:base/Stack";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Option "mo:base/Option";

module {

  // For convenience: from types module
  type IBTreeMap<K, V> = Types.IBTreeMap<K, V>;
  type Index = Types.Index;
  type Cursor<K, V> = Types.Cursor<K, V>;
  type Order = Order.Order;
  // For convenience: from node module
  type Node<K, V> = Node.Node<K, V>;

  public func new<K, V>(map: IBTreeMap<K, V>) : Iter<K, V>{
    // Initialize the cursors with the root of the map.
    let node = map.getRootNode();
    let next : Index = switch(map.getRootNode().getNodeType()) {
      // Iterate on internal nodes starting from the first child.
      case(#Internal) { #Child(0); };
      // Iterate on leaf nodes starting from the first entry.
      case(#Leaf) { #Entry(0); };
    };
    Iter({
      map;
      cursors = [{node; next;}];
      lower_bound = null;
      upper_bound = null;
    });
  };

  public func empty<K, V>(map: IBTreeMap<K, V>) : Iter<K, V>{
    Iter({
      map;
      cursors = [];
      lower_bound = null;
      upper_bound = null;
    });
  };

  public func newWithBounds<K, V>(map: IBTreeMap<K, V>, cursors: [Cursor<K, V>], lower_bound: K, upper_bound: K) : Iter<K, V>{
    Iter({
      map;
      cursors;
      lower_bound = ?lower_bound;
      upper_bound = ?upper_bound;
    });
  };

  type IterVariables<K, V> = {
    map: IBTreeMap<K, V>;
    cursors: [Cursor<K, V>];
    lower_bound: ?K;
    upper_bound: ?K;
  };

  /// An iterator over the entries of a [`BTreeMap`].
  /// Iterators are lazy and do nothing unless consumed
  public class Iter<K, V>(variables: IterVariables<K, V>) = self {
    
    // A reference to the map being iterated on.
    let map_: IBTreeMap<K, V> = variables.map;

    // A stack of cursors indicating the current position in the tree.
    var cursors_ = Stack.Stack<Cursor<K, V>>();
    for (cursor in Array.vals(variables.cursors)) {
      cursors_.push(cursor);
    };

    // Optional lower bound.
    // Iteration traps if it ever runs into a key that is lower than the lower bound.
    let lower_bound_ = variables.lower_bound;

    // Optional upper bound.
    // Iteration stops as soon as it runs into a key that is greater than the upper bound.
    let upper_bound_ = variables.upper_bound;

    // Verify the lower bound is not greater than the upper bound.
    Option.iterate(lower_bound_, func(lowest: K) {
      Option.iterate(upper_bound_, func(greatest: K) {
        if (Order.isGreater(map_.getKeyOrder()(lowest, greatest))){
          Debug.trap("The lower bound cannot be greater than the upper bound.");
        };
      });
    });

    public func next() : ?(K, V) {
      switch(cursors_.pop()) {
        case(?{node; next;}){
          switch(next){
            case(#Child(child_idx)){
              if (Nat64.toNat(child_idx) >= node.getChildren().size()){
                Debug.trap("Iterating over children went out of bounds.");
              };
              
              // After iterating on the child, iterate on the next _entry_ in this node.
              // The entry immediately after the child has the same index as the child's. 
              cursors_.push({
                node;
                next = #Entry(child_idx);
              });

              // Add the child to the top of the cursors to be iterated on first.
              let child = node.getChild(Nat64.toNat(child_idx));
              cursors_.push({
                node = child;
                next = switch(child.getNodeType()) {
                  // Iterate on internal nodes starting from the first child.
                  case(#Internal) { #Child(0); };
                  // Iterate on leaf nodes starting from the first entry.
                  case(#Leaf) { #Entry(0); };
                };
              });

              return self.next();
            };
            case(#Entry(entry_idx)){
              if (Nat64.toNat(entry_idx) >= node.getEntries().size()) {
                // No more entries to iterate on in this node.
                return self.next();
              };

              // Take the entry from the node.
              let entry = node.getEntry(Nat64.toNat(entry_idx));

              // Add to the cursors the next element to be traversed.
              cursors_.push({
                next = switch(node.getNodeType()){
                  // If this is an internal node, add the next child to the cursors.
                  case(#Internal) { #Child(entry_idx + 1); };
                  // If this is a leaf node, add the next entry to the cursors.
                  case(#Leaf) { #Entry(entry_idx + 1); };
                };
                node;
              });

              // Verify the key is greater than or equal to the lower bound, if any.
              Option.iterate(lower_bound_, func(lowest: K) {
                assert(not Order.isLess(map_.getKeyOrder()(entry.0, lowest)));
              });

              // Verify that the key is lower than or equal to the upper bound, if any.
              // Otherwise iteration is stopped.
              switch(upper_bound_){
                case(null) {};
                case(?greatest) {
                  if (Order.isGreater(map_.getKeyOrder()(entry.0, greatest))){
                    cursors_ := Stack.Stack<Cursor<K, V>>();
                    return null;
                  };
                };
              };

              return ?(entry.0, entry.1);
            };
          };
        };
        case(null){
          // The cursors are empty. Iteration is complete.
          null;
        };
      };
    };
    
  };

};