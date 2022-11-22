import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";

module {

  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;
  type Buffer<T> = Buffer.Buffer<T>;
  type Order = Order.Order;

  /// An indicator of the current position in the map.
  public type Cursor<K, V> = {
    node: INode<K, V>;
    next: Index;
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
  public type Entry<K ,V> = (K, V);

  public type NodeType = {
    #Leaf;
    #Internal;
  };

  public type INode<K, V> = {
    getEntries: () -> Buffer<Entry<K, V>>;
    getChildren: () -> Buffer<INode<K, V>>;
    getNodeType: () -> NodeType;
    getIdentifier: () -> Nat64;
    getMax: () -> Entry<K, V>;
    getMin: () -> Entry<K, V>;
    isFull: () -> Bool;
    swapEntry: (Nat, Entry<K, V>) -> Entry<K, V>;
    getKeyIdx: (K) -> Result<Nat, Nat>;
    getChild: (Nat) -> INode<K, V>;
    getEntry: (Nat) -> Entry<K, V>;
    getChildrenIdentifiers : () -> [Nat64];
    setChildren: (Buffer<INode<K, V>>) -> ();
    setEntries: (Buffer<Entry<K, V>>) -> ();
    setChild: (Nat, INode<K, V>) -> ();
    addChild: (INode<K, V>) -> ();
    addEntry: (Entry<K, V>) -> ();
    popEntry: () -> ?Entry<K, V>;
    popChild: () -> ?INode<K, V>;
    insertChild: (Nat, INode<K, V>) -> ();
    insertEntry: (Nat, Entry<K, V>) -> ();
    removeChild: (Nat) -> INode<K, V>;
    removeEntry: (Nat) -> Entry<K, V>;
    appendChildren: (Buffer<INode<K, V>>) -> ();
    appendEntries: (Buffer<Entry<K, V>>) -> ();
  };

  public type IBTreeMap<K, V> = {
    getRootNode : () -> INode<K, V>;
    getLength : () -> Nat64;
    getKeyOrder : () -> ((K, K) -> Order);
    insert : (k: K, v: V) -> ?V;
    get : (key: K) -> ?V;
    containsKey : (key: K) -> Bool;
    isEmpty : () -> Bool;
    remove : (key: K) -> ?V;
    iter : () -> IIter<K, V>;
    range : (K, K) -> IIter<K, V>;
  };

};