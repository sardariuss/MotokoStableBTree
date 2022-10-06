import Types "types";
import Conversion "conversion";
import Constants "constants";

import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Result "mo:base/Result";


module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;
  // For convenience: from types module
  type Address = Types.Address;
  type Bytes = Types.Bytes;
  type Memory = Types.Memory;
  type Entry = Types.Entry;
  type NodeType = Types.NodeType;

  let LAYOUT_VERSION: Nat8 = 1;
  let MAGIC = "BTN";
  let LEAF_NODE_TYPE: Nat8 = 0;
  let INTERNAL_NODE_TYPE: Nat8 = 1;
  // The size of Nat32 in bytes.
  let U32_SIZE: Nat = 4;
  // The size of an address in bytes.
  let ADDRESS_SIZE: Nat = 8;

  /// Loads a node from memory at the given address.
  public func load(
    address: Address,
    memory: Memory,
    max_key_size: Nat32,
    max_value_size: Nat32
  ) : Node {
    
    // Load the header.
    let header = loadNodeHeader(address, memory);
    if (header.magic != Blob.toArray(Text.encodeUtf8(MAGIC))) { Debug.trap("Bad magic."); };
    if (header.version != LAYOUT_VERSION)                     { Debug.trap("Unsupported version."); };

    // Load the entries.
    var entries = Buffer.Buffer<Entry>(0);
    var offset = SIZE_NODE_HEADER;
    for (_ in Iter.range(0, Nat16.toNat(header.num_entries - 1))){ // @todo: verify if it is really num_entries - 1
      // Read the key's size.
      let key_size = Conversion.bytesToNat32(memory.load(address + offset, U32_SIZE));
      offset += Nat64.fromNat(U32_SIZE);

      // Read the key.
      let key = memory.load(address + offset, Nat32.toNat(key_size));
      offset += Nat64.fromNat(Nat32.toNat(max_key_size));

      // Read the value's size.
      let value_size = Conversion.bytesToNat32(memory.load(address + offset, U32_SIZE));
      offset += Nat64.fromNat(U32_SIZE);

      // Read the value.
      let value = memory.load(address + offset, Nat32.toNat(value_size));
      offset += Nat64.fromNat(Nat32.toNat(max_value_size));

      entries.add((key, value));
    };

    // Load children if this is an internal 
    var children = Buffer.Buffer<Address>(0);
    if (header.node_type == INTERNAL_NODE_TYPE) {
      // The number of children is equal to the number of entries + 1.
      for (_ in Iter.range(0, Nat16.toNat(header.num_entries))){ // @todo: verify if it is really num_entries
        let child = Conversion.bytesToNat64(memory.load(address + offset, ADDRESS_SIZE));
        offset += Nat64.fromNat(ADDRESS_SIZE);
        children.add(child);
      };
      assert(children.size() == entries.size() + 1);
    };

    Node({
      address;
      entries = entries.toArray();
      children = children.toArray();
      node_type = getNodeType(header);
      max_key_size;
      max_value_size;
    });
  };

  /// Returns the size of a node in bytes.
  ///
  /// See the documentation of [`Node`] for the memory layout.
  public func size(max_key_size: Nat32, max_value_size: Nat32) : Bytes {
    let max_key_size_n64 = Nat64.fromNat(Nat32.toNat(max_key_size));
    let max_value_size_n64 = Nat64.fromNat(Nat32.toNat(max_value_size));

    let node_header_size = SIZE_NODE_HEADER;
    let entry_size = Nat64.fromNat(U32_SIZE) + max_key_size_n64 + max_value_size_n64 + Nat64.fromNat(U32_SIZE);
    let child_size = Nat64.fromNat(ADDRESS_SIZE);

    // @todo: verify the logic here, but at first sight it seems that Bytes::from implementation in rust does nothing useful but wrap the nat64 type
    node_header_size
      + getCapacity() * entry_size
      + (getCapacity() + 1) * child_size;
  };

  type NodeVariables = {
    address: Address;
    entries: [Entry];
    children: [Address];
    node_type: NodeType;
    max_key_size: Nat32;
    max_value_size: Nat32;
  };

  /// A node of a B-Tree.
  ///
  /// The node is stored in stable memory with the following layout:
  ///
  ///    |  NodeHeader  |  Entries (keys and values) |  Children  |
  ///
  /// Each node contains up to `CAPACITY` entries, each entry contains:
  ///     - size of key (4 bytes)
  ///     - key (`max_key_size` bytes)
  ///     - size of value (4 bytes)
  ///     - value (`max_value_size` bytes)
  ///
  /// Each node can contain up to `CAPACITY + 1` children, each child is 8 bytes.
  public class Node(variables : NodeVariables) {
    
    /// Members
    let address_ : Address = variables.address;
    var entries_ : [Entry] = variables.entries;
    var children_ : [Address] = variables.children;
    let node_type_ : NodeType = variables.node_type;
    let max_key_size_ : Nat32 = variables.max_key_size;
    let max_value_size_ : Nat32 = variables.max_value_size;

    /// Getters
    public func getAddress() : Address { address_; };
    public func getEntries() : [Entry] { entries_; };
    public func getChildren() : [Address] { children_; };
    public func getNodeType() : NodeType  { node_type_; };
    public func getMaxKeySize() : Nat32  { max_key_size_; };
    public func getMaxValueSize() : Nat32  { max_value_size_; };

    /// Saves the node to memory.
    public func save(memory: Memory) {
      switch(node_type_) {
        case(#Leaf){
          assert(children_.size() == 0);
        };
        case(#Internal){
          assert(children_.size() == entries_.size() + 1);
        };
      };

      // We should never be saving an empty 
      assert((entries_.size() != 0) or (children_.size() != 0));

      // Assert entries are sorted in strictly increasing order.
      //assert(entries_.windows(2).all(|e| e[0].0 < e[1].0)); // @todo

      let header = {
        magic = Blob.toArray(Text.encodeUtf8(MAGIC));
        version = LAYOUT_VERSION;
        node_type = switch(node_type_){
          case(#Leaf) { LEAF_NODE_TYPE; };
          case(#Internal) { INTERNAL_NODE_TYPE; };
        };
        num_entries = Nat16.fromNat(entries_.size());
      };

      saveNodeHeader(header, address_, memory);
      
      var offset = SIZE_NODE_HEADER;

      // Write the entries.
      for ((key, value) in Array.vals(entries_)) {
        // Write the size of the key.
        memory.store(address_ + offset, Conversion.nat32ToBytes(Nat32.fromNat(key.size())));
        offset += Nat64.fromNat(U32_SIZE);

        // Write the key.
        memory.store(address_ + offset, key);
        offset += Nat64.fromNat(Nat32.toNat(max_key_size_));

        // Write the size of the value.
        memory.store(address_ + offset, Conversion.nat32ToBytes(Nat32.fromNat(value.size())));
        offset += Nat64.fromNat(U32_SIZE);

        // Write the value.
        memory.store(address_ + offset, value);
        offset += Nat64.fromNat(Nat32.toNat(max_value_size_));
      };

      // Write the children
      for (child in Array.vals(children_)){
        memory.store(address_ + offset, Conversion.nat64ToBytes(child));
        offset += Nat64.fromNat(ADDRESS_SIZE); // Address size
      };
    };

    /// Returns the entry with the max key in the subtree.
    public func getMax(memory: Memory) : Entry {
      switch(node_type_){
        case(#Leaf) {
          if (entries_.size() == 0) { Debug.trap("A node can never be empty."); };
          entries_[entries_.size() - 1];
        };
        case(#Internal) { 
          if (children_.size() == 0) { Debug.trap("An internal node must have children."); };
          let last_child = load(children_[children_.size() - 1], memory, max_key_size_, max_value_size_);
          last_child.getMax(memory);
        };
      };
    };

    /// Returns the entry with min key in the subtree.
    // @todo: why do we assume a node can never be empty / an internal node must have children in getMax and not in getMin ?
    public func getMin(memory: Memory) : Entry {
      switch(node_type_){
        case(#Leaf) {
          // NOTE: a node can never be empty, so this access is safe.
          entries_[0];
        };
        case(#Internal) { 
          // NOTE: an internal node must have children, so this access is safe.
          let first_child = load(children_[0], memory, max_key_size_, max_value_size_);
          first_child.getMin(memory);
        };
      };
    };

    /// Returns true if the node cannot store anymore entries, false otherwise.
    public func isFull() : Bool {
      entries_.size() >= Nat64.toNat(getCapacity());
    };

    /// Swaps the entry at index `idx` with the given entry, returning the old entry.
    public func swapEntry(idx: Nat, entry: Entry) : Entry {
      let old_entry = entries_[idx];
      // @todo: shall we have an array of var Entry ?
      //entries_[idx] := entry;
      old_entry;
    };

    /// Searches for the key in the node's entries.
    ///
    /// If the key is found then `Result::Ok` is returned, containing the index
    /// of the matching key. If the value is not found then `Result::Err` is
    /// returned, containing the index where a matching key could be inserted
    /// while maintaining sorted order.
    public func getKeyIdx(key: [Nat8]) : Result<Nat, Nat> {
      // self.entries.binary_search_by(|e| e.0.as_slice().cmp(key)) // @todo
      #ok(0);
    };

    /// Add a child to the node's children
    /// @todo
    public func addChild(child: Address) {
    };

    /// @todo
    public func addEntry(entry: Entry) {
    };

    /// Add a child to the node's children
    /// @todo: see https://doc.rust-lang.org/beta/std/vec/struct.Vec.html#method.insert
    /// Should insert an element at position index within the vector, shifting all elements after it to the right.
    public func insertChild(idx: Nat, child: Address) {
    };

    /// Add an entry to the node's entries
    /// @todo: see https://doc.rust-lang.org/beta/std/vec/struct.Vec.html#method.insert
    /// Should insert an element at position index within the vector, shifting all elements after it to the right.
    public func insertEntry(idx: Nat, entry: Entry) {
    };

    /// @todo
    public func popEntry() : ?Entry {
      null;
    };

    /// @todo
    public func removeChild(idx: Nat) : Address {
      children_[0];
    };

    /// @todo
    public func popChild() : ?Address {
      null;
    };

    /// @todo
    public func removeEntry(idx: Nat) : Entry {
      entries_[0];
    };

    /// @todo
    public func appendEntries(entries: [Entry]) {
    
    };

    /// @todo
    public func setAddress(address: Address) {

    };

    /// @todo
    public func appendChildren(children: [Address]) {
    
    };

  };

  /// Deduce the node type based on the node header
  func getNodeType(header: NodeHeader) : NodeType {
    if (header.node_type == LEAF_NODE_TYPE) { return #Leaf; };
    if (header.node_type == INTERNAL_NODE_TYPE) { return #Internal; };
    Debug.trap("Unknown node type " # Nat8.toText(header.node_type));
  };

  /// The maximum number of entries per 
  func getCapacity() : Nat64 {
    assert(Constants.B > 0);
    2 * Nat64.fromNat(Int.abs(Constants.B)) - 1;
  };

  // A transient data structure for reading/writing metadata into/from stable memory.
  type NodeHeader = {
    magic: [Nat8]; // 3 bytes
    version: Nat8;
    node_type: Nat8;
    num_entries: Nat16;
  };

  let SIZE_NODE_HEADER : Nat64 = 7;

  func saveNodeHeader(header: NodeHeader, addr: Address, memory: Memory) {
    memory.store(addr,                                            header.magic);
    memory.store(addr + 3,                                    [header.version]);
    memory.store(addr + 3 + 1,                              [header.node_type]);
    memory.store(addr + 3 + 1 + 1, Conversion.nat16ToBytes(header.num_entries));
  };

  func loadNodeHeader(addr: Address, memory: Memory) : NodeHeader {
    let header = {
      magic =                               memory.load(addr,             3);
      version =                             memory.load(addr + 3,         1)[0];
      node_type =                           memory.load(addr + 3 + 1,     1)[0];
      num_entries = Conversion.bytesToNat16(memory.load(addr + 3 + 1 + 1, 2));
    };
    header;
  };

};