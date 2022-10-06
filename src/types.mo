import Buffer "mo:base/Buffer";
import Result "mo:base/Result";

module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  public type Address = Nat64;
  public type Bytes = Nat64;

  public type BytesConverter<T> = {
    fromBytes: ([Nat8]) -> T;
    toBytes: (T) -> [Nat8];
  };

  // @todo: rename in IMemory
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
    getEntries: () -> [Entry];
    getChildren: () -> [Address];
    getNodeType: () -> NodeType;
    getMaxKeySize: () -> Nat32;
    getMaxValueSize: () -> Nat32;
    save: (Memory) -> ();
    getMax: (Memory) -> Entry;
    getMin: (Memory) -> Entry;
    isFull: () -> Bool;
    swapEntry: (Nat, Entry) -> Entry;
    getKeyIdx: ([Nat8]) -> Result<Nat, Nat>;
    addChild: (Address) -> ();
    addEntry: (Entry) -> ();
    insertChild: (Nat, Address) -> ();
    insertEntry: (Nat, Entry) -> ();
    popEntry: () -> ?Entry;
    removeChild: (Nat) -> Address;
    popChild: () -> ?Address;
    removeEntry: (Nat) -> Entry;
    appendEntries: ([Entry]) -> ();
    setAddress: (Address) -> ();
    appendChildren: ([Address]) -> ();
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