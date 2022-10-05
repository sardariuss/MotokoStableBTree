import Types "types";
import Allocator "allocator";
import Conversion "conversion";
import Node "nodes"; // @todo
import Constants "constants";

import Result "mo:base/Result";
import Option "mo:base/Option";

module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // For convenience: from types module
  type Address = Types.Address;
  type Bytes = Types.Bytes;
  type Memory<M> = Types.Memory<M>;
  type NodeType = Types.NodeType;
  type Node = Types.Node;

  let LAYOUT_VERSION : Nat8 = 1;
  let MAGIC = "BTR";

  /// Initializes a `BTreeMap`.
  ///
  /// If the memory provided already contains a `BTreeMap`, then that
  /// map is loaded. Otherwise, a new `BTreeMap` instance is created.
  public func init<M, K, V>(
    memory : Memory<M>,
    max_key_size : Nat32,
    max_value_size : Nat32,
    key_converter: Conversion.BytesConverter<K>,
    value_converter: Conversion.BytesConverter<V>
  ) : BTreeMap<M, K, V> {
    if (memory.size(memory) == 0) {
      // Memory is empty. Create a new map.
      return new(memory, max_key_size, max_value_size, key_converter, value_converter);
    };

    // Check if the magic in the memory corresponds to a BTreeMap.
    let dst = memory.load(memory, 0, 3);
    if (dst != Blob.toArray(Text.encodeUtf8(MAGIC))) {
      // No BTreeMap found. Create a new instance.
      return new(memory, max_key_size, max_value_size, key_converter, value_converter);
    };
    
    // The memory already contains a BTreeMap. Load it.
    return load(memory, key_converter, value_converter);
  };

  /// Creates a new instance a `BTreeMap`.
  ///
  /// The given `memory` is assumed to be exclusively reserved for this data
  /// structure and that it starts at address zero. Typically `memory` will
  /// be an instance of `RestrictedMemory`.
  ///
  /// When initialized, the data structure has the following memory layout:
  ///
  ///    |  BTreeHeader  |  Allocator | ... free memory for nodes |
  ///
  /// See `Allocator` for more details on its own memory layout.
  public func new<M, K, V>(    
    memory : Memory<M>,
    max_key_size : Nat32,
    max_value_size : Nat32,
    key_converter: Conversion.BytesConverter<K>,
    value_converter: Conversion.BytesConverter<V>
  ) : BTreeMap<M, K, V> {
    // Because we assume that we have exclusive access to the memory,
    // we can store the `BTreeHeader` at address zero, and the allocator is
    // stored directly after the `BTreeHeader`.
    let allocator_addr = Constants.ADDRESS_0 + B_TREE_HEADER_SIZE;
    let btree = BTreeMap({
      root_addr = Constants.NULL;
      max_key_size = max_key_size;
      max_value_size = max_value_size;
      key_converter = key_converter;
      value_converter = value_converter;
      allocator = Allocator.initAllocator(memory, allocator_addr, Node.size(max_key_size, max_value_size));
      length : Nat64 = 0;
      memory = memory;
    });

    // @todo
    // btree.save();

    btree;
  };

  /// Loads the map from memory.
  public func load<M, K, V>(
    memory : Memory<M>,
    key_converter: Conversion.BytesConverter<K>,
    value_converter: Conversion.BytesConverter<V>
  ) : BTreeMap<M, K, V> {
    // Read the header from memory.
    let header = loadBTreeHeader(Constants.NULL, memory);
    let allocator_addr = Constants.ADDRESS_0 + B_TREE_HEADER_SIZE;

    BTreeMap({
      root_addr = header.root_addr;
      max_key_size = header.max_key_size;
      max_value_size = header.max_value_size;
      key_converter = key_converter;
      value_converter = value_converter;
      allocator = Allocator.loadAllocator(memory, allocator_addr);
      length = header.length;
      memory = memory;
    });
  };

  let B_TREE_HEADER_SIZE : Nat64 = 52;

  type BTreeHeader = {
    magic: [Nat8]; // 3 bytes
    version: Nat8;
    max_key_size: Nat32;
    max_value_size: Nat32;
    root_addr: Address;
    length: Nat64;
    // Additional space reserved to add new fields without breaking backward-compatibility.
    _buffer: [Nat8]; // 24 bytes
  };

  func saveBTreeHeader<M>(header: BTreeHeader, addr: Address, memory: Memory<M>) : Memory<M> {
    var updated_memory = memory;
    updated_memory := updated_memory.store(updated_memory, addr                        ,                                   header.magic);
    updated_memory := updated_memory.store(updated_memory, addr + 3                    ,                               [header.version]);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1                ,   Conversion.nat32ToBytes(header.max_key_size));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4            , Conversion.nat32ToBytes(header.max_value_size));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 4        ,      Conversion.nat64ToBytes(header.root_addr));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 4 + 8    ,         Conversion.nat64ToBytes(header.length));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 4 + 8 + 8,                                 header._buffer);
    updated_memory;
  };

  func loadBTreeHeader<M>(addr: Address, memory: Memory<M>) : BTreeHeader {
    let header = {
      magic =                                  memory.load(memory, addr                        , 3);
      version =                                memory.load(memory, addr + 3                    , 1)[0];
      max_key_size =   Conversion.bytesToNat32(memory.load(memory, addr + 3 + 1                , 4));
      max_value_size = Conversion.bytesToNat32(memory.load(memory, addr + 3 + 1 + 4            , 4));
      root_addr =      Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 4 + 4        , 8));
      length =         Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 4 + 4 + 8    , 8));
      _buffer =                                memory.load(memory, addr + 3 + 1 + 4 + 4 + 8 + 8, 24);
    };
    if (header.magic != Blob.toArray(Text.encodeUtf8(MAGIC))) { Debug.trap("Bad magic."); };
    if (header.version != LAYOUT_VERSION)                     { Debug.trap("Unsupported version."); };
    
    header;
  };

  type BTreeMapMembers<M, K, V> = {
    root_addr : Address;
    max_key_size : Nat32;
    max_value_size : Nat32;
    key_converter: Conversion.BytesConverter<K>;
    value_converter: Conversion.BytesConverter<V>;
    allocator : Allocator.Allocator<M>;
    length : Nat64;
    memory : Memory<M>;
  };

  type InsertError = {
    #KeyTooLarge : { given : Nat; max : Nat; };
    #ValueTooLarge : { given : Nat; max : Nat; };
  };

  class BTreeMap<M, K, V>(members: BTreeMapMembers<M, K, V>) = Self {
    
    // The address of the root node. If a root node doesn't exist, the address is set to NULL.
    var root_addr_ : Address = members.root_addr;

    // The maximum size a key can have.
    let max_key_size_ : Nat32 = members.max_key_size;

    // The maximum size a value can have.
    let max_value_size_ : Nat32 = members.max_value_size;

    /// To convert the key into/from bytes.
    let key_converter_ : Conversion.BytesConverter<K> = members.key_converter;
    
    /// To convert the value into/from bytes.
    let value_converter_ : Conversion.BytesConverter<V> = members.value_converter;

    // An allocator used for managing memory and allocating nodes.
    var allocator_ : Allocator.Allocator<M> = members.allocator;

    // The number of elements in the map.
    var length_ : Nat64 = members.length;

    /// The memory used to load/save the map.
    var memory_ : Memory<M> = members.memory;

    /// Inserts a key-value pair into the map.
    ///
    /// The previous value of the key, if present, is returned.
    ///
    /// The size of the key/value must be <= the max key/value sizes configured
    /// for the map. Otherwise, an `InsertError` is returned.
    public func insert(k: K, v: V) : Result<?V, InsertError> {
      let key = key_converter_.toBytes(k);
      let value = value_converter_.toBytes(v);

      // Verify the size of the key.
      if (key.size() > Nat32.toNat(max_key_size_)) {
        return #err(#KeyTooLarge {
          given = key.size();
          max = Nat32.toNat(max_key_size_);
        });
      };

      // Verify the size of the value.
      if (value.size() > Nat32.toNat(max_value_size_)) {
        return #err(#ValueTooLarge {
          given = value.size();
          max = Nat32.toNat(max_value_size_);
        });
      };

      let root = do {
        if (root_addr_ == Constants.NULL) {
          // No root present. Allocate one.
          let node = allocateNode(#Leaf);
          root_addr_ := node.address;
          save();
          node;
        } else {
          // Load the root from memory.
          var root = loadNode(root_addr_);

          // Check if the key already exists in the root.
          switch(Node.getKeyIdx(root, key)) {
            case(#ok(idx)){
              // The key exists. Overwrite it and return the previous value.
              let (updated_root, previous_node) = Node.swapEntry(root, idx, (key, value));
              memory_ := Node.save(updated_root, memory_);
              return #ok(?(value_converter_.fromBytes(previous_node.1)));
            };
            case(#err(_)){
              // If the root is full, we need to introduce a new node as the root.
              //
              // NOTE: In the case where we are overwriting an existing key, then introducing
              // a new root node isn't strictly necessary. However, that's a micro-optimization
              // that adds more complexity than it's worth.
              if (Node.isFull(root)) {
                // The root is full. Allocate a new node that will be used as the new root.
                var new_root = allocateNode(#Internal);
      
                // The new root has the old root as its only child.
                new_root := Node.addChild(new_root, root_addr_);
      
                // Update the root address.
                root_addr_ := new_root.address;
                save();
      
                // @todo: check if the split shouldn't be done before adding the root as child
                // Split the old (full) root. 
                new_root := splitChild(new_root, 0);
      
                new_root;
              } else {
                root;
              };
            };
          };
        };
      };
      // @todo
      // #ok(insertNonFull(root, key, value).map(v))
      #ok(?v);
    };

    // Inserts an entry into a node that is *not full*.
    func insertNonFull(node: Node, key: [Nat8], value: [Nat8]) : (Node, ?[Nat8]) {
      // We're guaranteed by the caller that the provided node is not full.
      assert(not Node.isFull(node));

      // Look for the key in the node.
      //switch(node.entries.binary_search_by(|e| e.0.cmp(&key)) {
      switch(Node.getKeyIdx(node, [])){ // @todo
        case(#ok(idx)){
          // The key is already in the node.
          // Overwrite it and return the previous value.
          let (updated_node, previous_node) = Node.swapEntry(node, idx, (key, value));

          memory_ := Node.save(updated_node, memory_);
          return (updated_node, ?(previous_node.1));
        };
        case(#err(idx)){
          // The key isn't in the node. `idx` is where that key should be inserted.

          switch(node.node_type) {
            case(#Leaf){
              // The node is a non-full leaf.
              // Insert the entry at the proper location.
              let updated_node = Node.insertEntry(node, idx, (key, value));
              
              memory_ := Node.save(updated_node, memory_);

              // Update the length.
              length_ += 1;
              save();

              // No previous value to return.
              return (updated_node, null);
            };
            case(#Internal){
              // The node is an internal node.
              // Load the child that we should add the entry to.
              var child = loadNode(node.children[idx]);

              if (Node.isFull(child)) {
                // Check if the key already exists in the child.
                switch(Node.getKeyIdx(child, key)) {
                  case(#ok(idx)){
                    // The key exists. Overwrite it and return the previous value.
                    let (updated_child, previous_node) = Node.swapEntry(child, idx, (key, value));

                    memory_ := Node.save(updated_child, memory_);
                    return (updated_child, ?previous_node.1);
                  };
                  case(#err(_)){
                    // The child is full. Split the child.
                    // @todo
                    //splitChild(idx);

                    // The children have now changed. Search again for
                    // the child where we need to store the entry in.
                    //let idx = node.get_key_idx(&key).unwrap_or_else(|idx| idx);
                    child := loadNode(node.children[0]); // @todo
                  };
                };
              };

              // The child should now be not full.
              assert(not Node.isFull(child));

              insertNonFull(child, key, value);
            };
          };
        };
      };
    };

    // Takes as input a nonfull internal `node` and index to its full child, then
    // splits this child into two, adding an additional child to `node`.
    //
    // Example:
    //
    //                          [ ... M   Y ... ]
    //                                  |
    //                 [ N  O  P  Q  R  S  T  U  V  W  X ]
    //
    //
    // After splitting becomes:
    //
    //                         [ ... M  S  Y ... ]
    //                                 / \
    //                [ N  O  P  Q  R ]   [ T  U  V  W  X ]
    //
    func splitChild(node: Node, full_child_idx: Nat) : Node {
      // @todo
      node;
    };

    func allocateNode(node_type: NodeType) : Node {
      let (updated_allocator, allocated_address) = Allocator.allocate(allocator_);
      allocator_ := updated_allocator;
      {
        address = allocated_address;
        entries = [];
        children = [];
        node_type;
        max_key_size = max_key_size_;
        max_value_size = max_value_size_;
      };
    };

    func loadNode(address: Address) : Node {
      Node.load(address, memory_, max_key_size_, max_value_size_);
    };

    // Saves the map to memory.
    func save() {
      let header : BTreeHeader = {
        magic = Blob.toArray(Text.encodeUtf8(MAGIC));
        version = LAYOUT_VERSION;
        root_addr = root_addr_;
        max_key_size = max_key_size_;
        max_value_size = max_value_size_;
        length = length_;
        _buffer = Array.freeze<Nat8>(Array.init<Nat8>(24, 0));
      };

      memory_ := saveBTreeHeader(header, Constants.ADDRESS_0, memory_);
    };

  };

};