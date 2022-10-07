import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import List "mo:base/List";
import Debug "mo:base/Debug";

module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;
  type Buffer<T> = Buffer.Buffer<T>;

  public type Address = Nat64;
  public type Bytes = Nat64;

  public type BytesConverter<T> = {
    fromBytes: ([Nat8]) -> T;
    toBytes: (T) -> [Nat8];
  };

  public type Memory = {
    size: () -> Nat64;
    store: (Nat64, [Nat8]) -> ();
    load: (Nat64, Nat) -> [Nat8];
  };

  /// An indicator of the current position in the map.
  public type Cursor = {
    #Address: Address;
    #Node: { node: INode; next: Index; };
  };

  /// An index into a node's child or entry.
  public type Index = {
    #Child: Nat64;
    #Entry: Nat64;
  };

  public type IIter<K, V> = {
    next: () -> ?(K, V);
  };

  // Entries in the node are key-value pairs and both are blobs.
  public type Entry = ([Nat8], [Nat8]);

  public type NodeType = {
    #Leaf;
    #Internal;
  };

  public type INode = {
    getAddress: () -> Address;
    getEntries: () -> Buffer<Entry>;
    getChildren: () -> Buffer<Address>;
    getNodeType: () -> NodeType;
    getMaxKeySize: () -> Nat32;
    getMaxValueSize: () -> Nat32;
    save: (Memory) -> ();
    getMax: (Memory) -> Entry;
    getMin: (Memory) -> Entry;
    isFull: () -> Bool;
    swapEntry: (Nat, Entry) -> Entry;
    getKeyIdx: ([Nat8]) -> Result<Nat, Nat>;
    getChild: (Nat) -> Address;
    getEntry: (Nat) -> Entry;
    addChild: (Address) -> ();
    addEntry: (Entry) -> ();
    insertChild: (Nat, Address) -> ();
    insertEntry: (Nat, Entry) -> ();
    popEntry: () -> ?Entry;
    removeChild: (Nat) -> Address;
    popChild: () -> ?Address;
    removeEntry: (Nat) -> Entry;
    appendEntries: (Buffer<Entry>) -> ();
    setAddress: (Address) -> ();
    appendChildren: (Buffer<Address>) -> ();
  };

  public type IAllocator = {
    getHeaderAddr: () -> Address;
    getAllocationSize: () -> Bytes;
    getNumAllocatedChunks: () -> Nat64;
    getFreeListHead: () -> Address;
    getMemory: () -> Memory;
    allocate: () ->  Address;
    deallocate: (Address) -> ();
    saveAllocator: () -> ();
    chunkSize: () -> Bytes;
  };

  public type InsertError = {
    #KeyTooLarge : { given : Nat; max : Nat; };
    #ValueTooLarge : { given : Nat; max : Nat; };
  };

  public type IBTreeMap<K, V> = {
    getRootAddr : () -> Address;
    getMaxKeySize : () -> Nat32;
    getMaxValueSize : () -> Nat32;
    getKeyConverter : () -> BytesConverter<K>;
    getValueConverter : () -> BytesConverter<V>;
    getAllocator : () -> IAllocator;
    getLength : () -> Nat64;
    getMemory : () -> Memory;
    insert : (k: K, v: V) -> Result<?V, InsertError>;
    get : (key: K) -> ?V;
    containsKey : (key: K) -> Bool;
    isEmpty : () -> Bool;
    remove : (key: K) -> ?V;
    iter : () -> IIter<K, V>;
     loadNode : (address: Address) -> INode;
  };

  /// Creates a buffer from an array
  public func toBuffer<T>(x :[T]) : Buffer<T>{
    let thisBuffer = Buffer.Buffer<T>(x.size());
    for(thisItem in x.vals()){
      thisBuffer.add(thisItem);
    };
    return thisBuffer;
  };

  /// Splits the buffers into two at the given index.
  /// The right buffer contains the element at the given index
  /// similarly to the Rust's vec::split_off method
  public func split<T>(idx: Nat, buffer: Buffer<T>) : (Buffer<T>, Buffer<T>){
    let left = buffer;
    var right = List.nil<T>();
    while(left.size() > idx){
      switch(left.removeLast()){
        case(null) { assert(false); };
        case(?last){
          right := List.push<T>(last, right);
        };
      };
    };
    (left, toBuffer<T>(List.toArray(List.reverse<T>(right))));
  };

  /// Insert an element into the buffer at given index
  /// @todo: shall this method return the new buffer instead ?
  public func insert<T>(idx: Nat, elem: T, buffer: Buffer<T>) {
    buffer.clear();
    let (left, right) = split<T>(idx, buffer);
    buffer.append(left);
    buffer.add(elem);
    buffer.append(right);
  };

  /// Remove an element from the buffer at the given index
  /// Traps if index is out of bounds.
  public func remove<T>(idx: Nat, buffer: Buffer<T>) : T {
    buffer.clear();
    let (left, right) = split<T>(idx + 1, buffer);
    switch(left.removeLast()){
      case(null) { Debug.trap("Index is out of bounds."); };
      case(?elem) {
        buffer.append(left);
        buffer.append(right);
        elem;
      };
    };
  };

};