import Buffer "mo:base/Buffer";


module {

  public type Address = Nat64;
  public type Bytes = Nat64;

  public type Memory<T> = {
    size: (Memory<T>) -> Nat64;
    store: (Memory<T>, Nat64, [Nat8]) -> Memory<T>;
    load: (Memory<T>, Nat64, Nat) -> [Nat8];
    t: T;
  };

  public type BTreeMap<M, K, V> = {
    root_addr: Address;
  }; // @todo: remove from here

  // Entries in the node are key-value pairs and both are blobs.
  public type Entry = ([Nat8], [Nat8]);

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

  public type MyType = {
    myFunc: () -> Nat;
  };


  //////////////////////////////////////////////////////////////////////
  // The following functions easily creates a buffer from an arry of any type
  //////////////////////////////////////////////////////////////////////

  public func toBuffer<T>(x :[T]) : Buffer.Buffer<T>{
    let thisBuffer = Buffer.Buffer<T>(x.size());
    for(thisItem in x.vals()){
      thisBuffer.add(thisItem);
    };
    return thisBuffer;
  };

};