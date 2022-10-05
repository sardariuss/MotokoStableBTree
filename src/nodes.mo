import Types "types";
import Conversion "conversion";

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
import Result "mo:base/Result";


module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // For convenience: from types module
  type Address = Types.Address;
  type Bytes = Types.Bytes;
  type Memory<M> = Types.Memory<M>;
  type Entry = Types.Entry;
  type NodeType = Types.NodeType;
  type Node = Types.Node;

  /// The minimum degree to use in the btree.
  /// This constant is taken from Rust's std implementation of BTreeMap.
  public let B : Nat64 = 6;
  let LAYOUT_VERSION: Nat8 = 1;
  let MAGIC = "BTN";
  let LEAF_NODE_TYPE: Nat8 = 0;
  let INTERNAL_NODE_TYPE: Nat8 = 1;
  // The size of Nat32 in bytes.
  let U32_SIZE: Nat = 4;
  // The size of an address in bytes.
  let ADDRESS_SIZE: Nat = 8;

  /// Loads a node from memory at the given address.
  public func load<M>(
    address: Address,
    memory: Memory<M>,
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
      let key_size = Conversion.bytesToNat32(memory.load(memory, address + offset, U32_SIZE));
      offset += Nat64.fromNat(U32_SIZE);

      // Read the key.
      let key = memory.load(memory, address + offset, Nat32.toNat(key_size));
      offset += Nat64.fromNat(Nat32.toNat(max_key_size));

      // Read the value's size.
      let value_size = Conversion.bytesToNat32(memory.load(memory, address + offset, U32_SIZE));
      offset += Nat64.fromNat(U32_SIZE);

      // Read the value.
      let value = memory.load(memory, address + offset, Nat32.toNat(value_size));
      offset += Nat64.fromNat(Nat32.toNat(max_value_size));

      entries.add((key, value));
    };

    // Load children if this is an internal node.
    var children = Buffer.Buffer<Address>(0);
    if (header.node_type == INTERNAL_NODE_TYPE) {
      // The number of children is equal to the number of entries + 1.
      for (_ in Iter.range(0, Nat16.toNat(header.num_entries))){ // @todo: verify if it is really num_entries
        let child = Conversion.bytesToNat64(memory.load(memory, address + offset, ADDRESS_SIZE));
        offset += Nat64.fromNat(ADDRESS_SIZE);
        children.add(child);
      };
      assert(children.size() == entries.size() + 1);
    };

    {
      address;
      entries = entries.toArray();
      children = children.toArray();
      node_type = getNodeType(header);
      max_key_size;
      max_value_size;
    };
  };

  /// Saves the node to memory.
  public func save<M>(node: Node, memory: Memory<M>) : Memory<M> {
    switch(node.node_type) {
      case(#Leaf){
        assert(node.children.size() == 0);
      };
      case(#Internal){
        assert(node.children.size() == node.entries.size() + 1);
      };
    };

    // We should never be saving an empty node.
    assert((node.entries.size() != 0) or (node.children.size() != 0));

    // Assert entries are sorted in strictly increasing order.
    //assert(node.entries.windows(2).all(|e| e[0].0 < e[1].0)); // @todo

    let header = {
      magic = Blob.toArray(Text.encodeUtf8(MAGIC));
      version = LAYOUT_VERSION;
      node_type = switch(node.node_type){
        case(#Leaf) { LEAF_NODE_TYPE; };
        case(#Internal) { INTERNAL_NODE_TYPE; };
      };
      num_entries = Nat16.fromNat(node.entries.size());
    };

    var updated_memory = saveNodeHeader(header, node.address, memory);
    
    var offset = SIZE_NODE_HEADER;

    // Write the entries.
    for ((key, value) in Array.vals(node.entries)) {
      // Write the size of the key.
      updated_memory := memory.store(updated_memory, node.address + offset, Conversion.nat32ToBytes(Nat32.fromNat(key.size())));
      offset += Nat64.fromNat(U32_SIZE);

      // Write the key.
      updated_memory := memory.store(updated_memory, node.address + offset, key);
      offset += Nat64.fromNat(Nat32.toNat(node.max_key_size));

      // Write the size of the value.
      updated_memory := memory.store(updated_memory, node.address + offset, Conversion.nat32ToBytes(Nat32.fromNat(value.size())));
      offset += Nat64.fromNat(U32_SIZE);

      // Write the value.
      updated_memory := memory.store(updated_memory, node.address + offset, value);
      offset += Nat64.fromNat(Nat32.toNat(node.max_value_size));
    };

    // Write the children
    for (child in Array.vals(node.children)){
      updated_memory := memory.store(updated_memory, node.address + offset, Conversion.nat64ToBytes(child));
      offset += Nat64.fromNat(ADDRESS_SIZE); // Address size
    };

    updated_memory;
  };

  /// Returns the entry with the max key in the subtree.
  public func getMax<M>(node: Node, memory: Memory<M>) : Entry {
    switch(node.node_type){
      case(#Leaf) {
        if (node.entries.size() == 0) { Debug.trap("A node can never be empty."); };
        node.entries[node.entries.size() - 1];
      };
      case(#Internal) { 
        if (node.children.size() == 0) { Debug.trap("An internal node must have children."); };
        let last_child = load(node.children[node.children.size() - 1], memory, node.max_key_size, node.max_value_size);
        getMax(last_child, memory);
      };
    };
  };

  /// Returns the entry with min key in the subtree.
  // @todo: why do we assume a node can never be empty / an internal node must have children in getMax and not in getMin ?
  public func getMin<M>(node: Node, memory: Memory<M>) : Entry {
    switch(node.node_type){
      case(#Leaf) {
        // NOTE: a node can never be empty, so this access is safe.
        node.entries[0];
      };
      case(#Internal) { 
        // NOTE: an internal node must have children, so this access is safe.
        let first_child = load(node.children[0], memory, node.max_key_size, node.max_value_size);
        getMin(first_child, memory);
      };
    };
  };

  /// Returns true if the node cannot store anymore entries, false otherwise.
  public func isFull(node: Node) : Bool {
    node.entries.size() >= Nat64.toNat(getCapacity());
  };

  /// Swaps the entry at index `idx` with the given entry, returning the old entry.
  public func swapEntry(node: Node, idx: Nat, entry: Entry) : (Node, Entry) {
    var entries = Array.thaw<Entry>(node.entries);
    let old_entry = entries[idx];
    entries[idx] := entry;
    (
      {
        address = node.address;
        entries = Array.freeze<Entry>(entries);
        children = node.children;
        node_type = node.node_type;
        max_key_size = node.max_key_size;
        max_value_size = node.max_value_size;
      },
      old_entry
    );
  };

  /// Searches for the key in the node's entries.
  ///
  /// If the key is found then `Result::Ok` is returned, containing the index
  /// of the matching key. If the value is not found then `Result::Err` is
  /// returned, containing the index where a matching key could be inserted
  /// while maintaining sorted order.
  public func getKeyIdx(node: Node, key: Blob) : Result<Nat, Nat> {
    // self.entries.binary_search_by(|e| e.0.as_slice().cmp(key)) // @todo
    #ok(0);
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

  /// Deduce the node type based on the node header
  func getNodeType(header: NodeHeader) : NodeType {
    if (header.node_type == LEAF_NODE_TYPE) { return #Leaf; };
    if (header.node_type == INTERNAL_NODE_TYPE) { return #Internal; };
    Debug.trap("Unknown node type " # Nat8.toText(header.node_type));
  };

  /// The maximum number of entries per node.
  func getCapacity() : Nat64 {
    2 * B - 1;
  };

  // A transient data structure for reading/writing metadata into/from stable memory.
  type NodeHeader = {
    magic: [Nat8]; // 3 bytes
    version: Nat8;
    node_type: Nat8;
    num_entries: Nat16;
  };

  let SIZE_NODE_HEADER : Nat64 = 7;

  func saveNodeHeader<M>(header: NodeHeader, addr: Address, memory: Memory<M>) : Memory<M> {
    var updated_memory = memory;
    updated_memory := updated_memory.store(updated_memory, addr,                                            header.magic);
    updated_memory := updated_memory.store(updated_memory, addr + 3,                                    [header.version]);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1,                              [header.node_type]);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 1, Conversion.nat16ToBytes(header.num_entries));
    updated_memory;
  };

  func loadNodeHeader<M>(addr: Address, memory: Memory<M>) : NodeHeader {
    let header = {
      magic =                               memory.load(memory, addr,             3);
      version =                             memory.load(memory, addr + 3,         1)[0];
      node_type =                           memory.load(memory, addr + 3 + 1,     1)[0];
      num_entries = Conversion.bytesToNat16(memory.load(memory, addr + 3 + 1 + 1, 2));
    };
    header;
  };

};