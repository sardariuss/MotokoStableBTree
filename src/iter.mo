import Types "types";
import Node "node";
import Constants "constants";
import BTreeMap "btreemap";

import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Stack "mo:base/Stack";
import Array "mo:base/Array";

module {

  // For convenience: from base module

  // For convenience: from types module
  type Address = Types.Address;
  type BTreeMap<K, V> = BTreeMap.BTreeMap<K, V>;
  type NodeType = Types.NodeType;
  type Entry = Types.Entry;
  
  // For convenience: from node module
  type Node = Node.Node;

  /// An indicator of the current position in the map.
  public type Cursor = {
    #Address: Address;
    #Node: { node: Node; next: Index; };
  };

  /// An index into a node's child or entry.
  public type Index = {
    #Child: Nat64;
    #Entry: Nat64;
  };

  /// An iterator over the entries of a [`BTreeMap`].
  // #[must_use = "iterators are lazy and do nothing unless consumed"] @todo
  // @todo: have different functions for init like in Rust
  class Iter<K, V>(map: BTreeMap<K, V>, cursors: ?[Cursor], prefix: ?[Nat8], offset: ?[Nat8]) = Self {
    
    // A reference to the map being iterated on. // @todo: here it's a copy, is there any alternative in Motoko ?
    let map_: BTreeMap<K, V> = map;

    // A stack of cursors indicating the current position in the tree.
    var cursors_ = Stack.Stack<Cursor>();
    switch(cursors){
      case(null) { 
        if (map.getRootAddr() != Constants.NULL) {
          cursors_.push(#Address(map.getRootAddr()));
        };
      };
      case(?cursors) {
        for (cursor in Array.vals(cursors)) {
          cursors_.push(cursor);
        };
      };
    };

    // An optional prefix that the keys of all the entries returned must have.
    // Iteration stops as soon as it runs into a key that doesn't have this prefix.
    var prefix_: ?[Nat8] = switch(cursors){
      case(null) { null; };
      case(_) { prefix };
    };

    // An optional offset to begin iterating from in the keys with the same prefix.
    // Used only in the case that prefix is also set.
    var offset_: ?[Nat8] = switch(cursors){
      case(null) { null; };
      case(_) {
        switch(prefix){
          case(null) { null; };
          case(_) { offset };
        };
      };
    };

    public func next() : ?(K, V) {
      switch(cursors_.pop()) {
        case(?cursor){
          switch(cursor){
            case(#Address(address)){
              if (address != Constants.NULL){
                // Load the node at the given address, and add it to the cursors.
                let node = map_.loadNode(address);

                cursors_.push(#Node{
                  next = switch(node.getNodeType()) {
                    // Iterate on internal nodes starting from the first child.
                    case(#Internal) { #Child(0); };
                    // Iterate on leaf nodes starting from the first entry.
                    case(#Leaf) { #Entry(0); };
                  };
                  node;
                });
              };
              return Self.next();
            };
            case(#Node({node; next;})){
              switch(next){
                case(#Child(child_idx)){
                  if (Nat64.toNat(child_idx) >= node.getChildren().size()){
                    Debug.print("Iterating over children went out of bounds.");
                  };
                  
                  // After iterating on the child, iterate on the next _entry_ in this node.
                  // The entry immediately after the child has the same index as the child's.
                  cursors_.push(#Node {
                    node;
                    next = #Entry(child_idx);
                  });

                  // Add the child to the top of the cursors to be iterated on first.
                  let child_address = node.getChildren()[Nat64.toNat(child_idx)];
                  cursors_.push(#Address(child_address));

                  return Self.next();
                };
                case(#Entry(entry_idx)){
                  if (Nat64.toNat(entry_idx) >= node.getEntries().size()) {
                    // No more entries to iterate on in this node.
                    return Self.next();
                  };

                  // Take the entry from the node. It's swapped with an empty element to
                  // avoid cloning.
                  // @todo: verify that
                  let entry = node.swapEntry(Nat64.toNat(entry_idx), ([], []));

                  // Add to the cursors the next element to be traversed.
                  cursors_.push(#Node {
                    next = switch(node.getNodeType()){
                      // If this is an internal node, add the next child to the cursors.
                      case(#Internal) { #Child(entry_idx + 1); };
                      // If this is a leaf node, add the next entry to the cursors.
                      case(#Leaf) { #Entry(entry_idx + 1); };
                    };
                    node;
                  });

                  // If there's a prefix, verify that the key has that given prefix.
                  // Otherwise iteration is stopped.
                  switch(prefix_){
                    case(null) {};
                    case(?prefix){
                      var starts_with : Bool = true;
                      for (i in Array.keys(prefix)){
                        starts_with := starts_with and (entry.0[i] == prefix[i]);
                      };
                      if (not starts_with){
                        cursors_ := Stack.Stack<Cursor>();
                        return null;
                      } else switch(offset_) {
                        case(null) {};
                        case(?offset){

                          let prefix_with_offset = Types.toBuffer<Nat8>(prefix);
                          prefix_with_offset.append(Types.toBuffer<Nat8>(offset));
                          
                          // Clear all cursors to avoid needless work in subsequent calls.
                          // @todo: need to be able to lexicographically compare entry.0 with prefix_with_offset
                          // see https://doc.rust-lang.org/std/cmp/trait.Ord.html#lexicographical-comparison
                          if (false) {
                            cursors_ := Stack.Stack<Cursor>();
                            return null;
                          };
                        };
                      };
                    };
                  };
                  // @todo: requires the storable functions for key and values (will be stored in the btreemap)
                  //return ?(entry.0, entry.1);
                  return null;
                };
              };
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