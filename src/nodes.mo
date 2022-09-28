import Types "types";
import AlignedStruct "alignedStruct";

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
  type Variant = Types.Variant;
  type AlignedStruct = Types.AlignedStruct;
  type AlignedStructDefinition = Types.AlignedStructDefinition;
  type Memory<M> = Types.Memory<M>;

  /// The minimum degree to use in the btree.
  /// This constant is taken from Rust's std implementation of BTreeMap.
  public let B : Nat64 = 6;
  let LAYOUT_VERSION: Nat8 = 1;
  let MAGIC = "BTN";
  let LEAF_NODE_TYPE: Nat8 = 0;
  let INTERNAL_NODE_TYPE: Nat8 = 1;
  // The size of Nat32 in bytes.
  let U32_SIZE: Bytes = 4;
  // The size of an address in bytes.
  let ADDRESS_SIZE: Bytes = 8;

  // Entries in the node are key-value pairs and both are blobs.
  public type Entry = (Blob, Blob);

  public type NodeType = {
    #Leaf;
    #Internal;
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
  public type Node = {
    address: Address;
    entries: [Entry];
    children: [Address];
    node_type: NodeType;
    max_key_size: Nat32;
    max_value_size: Nat32;
  };

  /// Loads a node from memory at the given address.
  public func load<M>(
    address: Address,
    memory: Memory<M>,
    max_key_size: Nat32,
    max_value_size: Nat32
  ) : Node {
    
    // Load the header.
    let header = loadNodeHeader(address, memory);
    if (header.magic != Text.encodeUtf8(MAGIC)) { Debug.trap("Bad magic."); };
    if (header.version != LAYOUT_VERSION) { Debug.trap("Unsupported version."); };

    // Load the entries.
    var entries = Buffer.Buffer<Entry>(0);
    var offset = sizeNodeHeader();
    for (_ in Iter.range(0, Nat16.toNat(header.num_entries - 1))){ // @todo: verify if it is really num_entries - 1
      // Read the key's size.
      let key_size = readNat32(memory, address + offset);
      offset += U32_SIZE;

      // Read the key.
      let key = readBlob(memory, address + offset, Nat32.toNat(key_size));
      offset += Nat64.fromNat(Nat32.toNat(max_key_size));

      // Read the value's size.
      let value_size = readNat32(memory, address + offset);
      offset += U32_SIZE;

      // Read the value.
      let value = readBlob(memory, address + offset, Nat32.toNat(value_size));
      offset += Nat64.fromNat(Nat32.toNat(max_value_size));

      entries.add((key, value));
    };

    // Load children if this is an internal node.
    var children = Buffer.Buffer<Address>(0);
    if (header.node_type == INTERNAL_NODE_TYPE) {
      // The number of children is equal to the number of entries + 1.
      for (_ in Iter.range(0, Nat16.toNat(header.num_entries))){ // @todo: verify if it is really num_entries
        let child = readNat64(memory, address + offset);
        offset += ADDRESS_SIZE;
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
      magic = Text.encodeUtf8(MAGIC);
      version = LAYOUT_VERSION;
      node_type = switch(node.node_type){
        case(#Leaf) { LEAF_NODE_TYPE; };
        case(#Internal) { INTERNAL_NODE_TYPE; };
      };
      num_entries = Nat16.fromNat(node.entries.size());
    };

    var updated_memory = saveNodeHeader(header, node.address, memory);
    
    var offset = sizeNodeHeader();

    // Write the entries.
    for ((key, value) in Array.vals(node.entries)) {
      // Write the size of the key.
      updated_memory := writeNat32<M>(updated_memory, node.address + offset, Nat32.fromNat(key.size()));
      offset += U32_SIZE;

      // Write the key.
      updated_memory := writeBlob(updated_memory, node.address + offset, key);
      offset += Nat64.fromNat(Nat32.toNat(node.max_key_size));

      // Write the size of the value.
      updated_memory := writeNat32<M>(updated_memory, node.address + offset, Nat32.fromNat(value.size()));
      offset += U32_SIZE;

      // Write the value.
      updated_memory := writeBlob(updated_memory, node.address + offset, value);
      offset += Nat64.fromNat(Nat32.toNat(node.max_value_size));
    };

    // Write the children
    for (child in Array.vals(node.children)){
      updated_memory := writeNat64<M>(updated_memory, node.address + offset, child);
      offset += ADDRESS_SIZE; // Address size
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

    let node_header_size = sizeNodeHeader();
    let entry_size = U32_SIZE + max_key_size_n64 + max_value_size_n64 + U32_SIZE;
    let child_size = ADDRESS_SIZE;

    // @todo: verify the logic here, but at first sight it seems that Bytes::from implementation in rust does nothing useful but wrap the nat64 type
    node_header_size
      + getCapacity() * entry_size
      + (getCapacity() + 1)  * child_size;
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
    magic: Blob; // 3 bytes
    version: Nat8;
    node_type: Nat8;
    num_entries: Nat16;
  };

  let NODE_HEADER_STRUCT_DEFINITION : AlignedStructDefinition = [
    #Blob(3), // magic
    #Nat8,    // version
    #Nat8,    // node_type
    #Nat16,   // num_entries
  ];

  func saveNodeHeader<M>(node_header: NodeHeader, address: Address, memory: Memory<M>) : Memory<M> {
    memory.store(memory, address, nodeHeaderToAlignedStruct(node_header));
  };

  func loadNodeHeader<M>(address: Address, memory: Memory<M>) : NodeHeader {
    let header = structToNodeHeader(memory.load(memory, address, NODE_HEADER_STRUCT_DEFINITION));
    if (header.magic != Text.encodeUtf8(MAGIC)) { Debug.trap("Bad magic."); };
    if (header.version != LAYOUT_VERSION) { Debug.trap("Unsupported version."); };
    
    header;
  };

  func sizeNodeHeader() : Nat64 {
    AlignedStruct.sizeDefinition(NODE_HEADER_STRUCT_DEFINITION);
  };

  func nodeHeaderToAlignedStruct(node_header: NodeHeader) : AlignedStruct {
    var buffer = Buffer.Buffer<Variant>(0);
    // Convert bool to nat8
    buffer.add(#Blob(node_header.magic));
    buffer.add(#Nat8(node_header.version));
    buffer.add(#Nat8(node_header.node_type));
    buffer.add(#Nat16(node_header.num_entries));
    // Return array
    buffer.toArray();
  };

  func structToNodeHeader(struct: AlignedStruct) : NodeHeader {
    {
      magic       = switch(struct[0]){ case(#Blob(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      version     = switch(struct[1]){ case(#Nat8(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      node_type   = switch(struct[2]){ case(#Nat8(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      num_entries = switch(struct[3]){ case(#Nat16(value)) { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
    };
  };

  func readNat32<M>(memory: Memory<M>, address: Address) : Nat32 {
    let alignedStruct = memory.load(memory, address, [#Nat32]);
    switch(alignedStruct[0]){
      case(#Nat32(value)) { value; };
      case(_) { Debug.trap("Unexpected variant type."); };
    };
  };

  func readNat64<M>(memory: Memory<M>, address: Address) : Nat64 {
    let alignedStruct = memory.load(memory, address, [#Nat64]);
    switch(alignedStruct[0]){
      case(#Nat64(value)) { value; };
      case(_) { Debug.trap("Unexpected variant type."); };
    };
  };

  func readBlob<M>(memory: Memory<M>, address: Address, size: Nat) : Blob {
    let alignedStruct = memory.load(memory, address, [#Blob(Nat64.fromNat(size))]);
    switch(alignedStruct[0]){
      case(#Blob(value)) { value; };
      case(_) { Debug.trap("Unexpected variant type."); };
    };
  };

  func writeNat32<M>(memory: Memory<M>, address: Address, value: Nat32) : Memory<M> {
    memory.store(memory, address, [#Nat32(value)]);
  };

  func writeNat64<M>(memory: Memory<M>, address: Address, value: Nat64) : Memory<M> {
    memory.store(memory, address, [#Nat64(value)]);
  };

  func writeBlob<M>(memory: Memory<M>, address: Address, value: Blob) : Memory<M> {
    memory.store(memory, address, [#Blob(value)]);
  };
  

};