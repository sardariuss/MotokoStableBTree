import Types "types";
import Constants "constants";
import Utils "utils";

import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Order "mo:base/Order";

module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;
  type Buffer<T> = Buffer.Buffer<T>;
  type Order = Order.Order;
  // For convenience: from types module
  type Entry<K, V> = Types.Entry<K, V>;
  type NodeType = Types.NodeType;

  /// A node of a B-Tree.
  ///
  /// Each node can contain up to `CAPACITY + 1` children.
  public class Node<K, V>(key_order: (K, K) -> Order, node_type: NodeType, node_identifier: Nat64) {
    
    /// Members
    var entries_ = Buffer.Buffer<Entry<K, V>>(0);
    var children_ = Buffer.Buffer<Node<K, V>>(0);
    let key_order_ = key_order;
    let node_type_ = node_type;
    let node_identifier_ = node_identifier;

    /// Getters
    public func getEntries() : Buffer<Entry<K, V>> { entries_; };
    public func getChildren() : Buffer<Node<K, V>> { children_; };
    public func getNodeType() : NodeType  { node_type_; };
    public func getIdentifier() : Nat64  { node_identifier_; };

    /// Returns the entry with the max key in the subtree.
    public func getMax() : Entry<K, V> {
      switch(node_type_){
        case(#Leaf) {
          // NOTE: a node can never be empty, so this access is safe.
          if (entries_.size() == 0) { Debug.trap("A node can never be empty."); };
          entries_.get(entries_.size() - 1);
        };
        case(#Internal) { 
          // NOTE: an internal node must have children, so this access is safe.
          if (children_.size() == 0) { Debug.trap("An internal node must have children."); };
          let last_child = children_.get(children_.size() - 1);
          last_child.getMax();
        };
      };
    };

    /// Returns the entry with min key in the subtree.
    public func getMin() : Entry<K, V> {
      switch(node_type_){
        case(#Leaf) {
          // NOTE: a node can never be empty, so this access is safe.
          if (entries_.size() == 0) { Debug.trap("A node can never be empty."); };
          entries_.get(0);
        };
        case(#Internal) { 
          // NOTE: an internal node must have children, so this access is safe.
          if (children_.size() == 0) { Debug.trap("An internal node must have children."); };
          let first_child = children_.get(0);
          first_child.getMin();
        };
      };
    };

    /// Returns true if the node cannot store anymore entries, false otherwise.
    public func isFull() : Bool {
      entries_.size() >= Nat64.toNat(getCapacity());
    };

    /// Swaps the entry at index `idx` with the given entry, returning the old entry.
    public func swapEntry(idx: Nat, entry: Entry<K, V>) : Entry<K, V> {
      let old_entry = entries_.get(idx);
      entries_.put(idx, entry);
      old_entry;
    };

    /// Searches for the key in the node's entries.
    ///
    /// If the key is found then `Result::Ok` is returned, containing the index
    /// of the matching key. If the value is not found then `Result::Err` is
    /// returned, containing the index where a matching key could be inserted
    /// while maintaining sorted order.
    public func getKeyIdx(key: K) : Result<Nat, Nat> {
      Utils.binarySearch(getKeys(), key_order_, key);
    };

    /// Get the child at the given index. Traps if the index is superior than the number of children.
    public func getChild(idx: Nat) : Node<K, V> {
      children_.get(idx);
    };

    /// Get the entry at the given index. Traps if the index is superior than the number of entries.
    public func getEntry(idx: Nat) : Entry<K, V> {
      entries_.get(idx);
    };

    public func getChildrenIdentifiers() : [Nat64] {
      let identifiers = Buffer.Buffer<Nat64>(children_.size());
      for (child in children_.vals()){
        identifiers.add(child.getIdentifier());
      };
      identifiers.toArray();
    };

    /// Set the node's children
    public func setChildren(children: Buffer<Node<K, V>>) {
      children_ := children;
    };

    /// Set the node's entries
    public func setEntries(entries: Buffer<Entry<K, V>>) {
      entries_ := entries;
    };

    /// Add a child at the end of the node's children.
    public func addChild(child: Node<K, V>) {
      children_.add(child);
    };

    /// Add an entry at the end of the node's entries.
    public func addEntry(entry: Entry<K, V>) {
      entries_.add(entry);
    };

    /// Set the child at given index
    public func setChild(idx: Nat, child: Node<K, V>) {
      children_.put(idx, child);
    };

    /// Remove the child at the end of the node's children.
    public func popChild() : ?Node<K, V> {
      children_.removeLast();
    };

    /// Remove the entry at the end of the node's entries.
    public func popEntry() : ?Entry<K, V> {
      entries_.removeLast();
    };

    /// Insert a child into the node's children at the given index.
    public func insertChild(idx: Nat, child: Node<K, V>) {
      Utils.insert(children_, idx, child);
    };

    /// Insert an entry into the node's entries at the given index.
    public func insertEntry(idx: Nat, entry: Entry<K, V>) {
      Utils.insert(entries_, idx, entry);
    };

    /// Remove the child from the node's children at the given index.
    public func removeChild(idx: Nat) : Node<K, V> {
      Utils.remove(children_, idx);
    };

    /// Remove the entry from the node's entries at the given index.
    public func removeEntry(idx: Nat) : Entry<K, V> {
      Utils.remove(entries_, idx);
    };

    /// Append the given children to the node's children
    public func appendChildren(children: Buffer<Node<K, V>>) {
      children_.append(children);
    };

    /// Append the given entries to the node's entries
    public func appendEntries(entries: Buffer<Entry<K, V>>) {
      entries_.append(entries);
    };

    func getKeys() : [K] {
      Array.map(entries_.toArray(), func(entry: Entry<K, V>) : K { entry.0; });
    };

  };

  /// The maximum number of entries per node.
  public func getCapacity() : Nat64 {
    2 * Nat64.fromNat(Constants.B) - 1;
  };

};