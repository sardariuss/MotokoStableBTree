import Types "types";
import Node "node";
import Constants "constants";
import Iter "iter";
import Utils "utils";

import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";

module {

  // For convenience: from base module
  type Order = Order.Order;
  // For convenience: from types module
  type NodeType = Types.NodeType;
  type Entry<K, V> = Types.Entry<K, V>;
  type Cursor<K, V> = Types.Cursor<K, V>;
  // For convenience: from node module
  type Node<K, V> = Node.Node<K, V>;
  // For convenience: from iter module
  type Iter<K, V> = Iter.Iter<K, V>;

  public class BTreeMap<K, V>(key_order: (K, K) -> Order) = self {
    
    /// Members
    // The root node.
    var root_node_ = Node.Node<K, V>(key_order, #Leaf, 0);
    // The number of elements in the map.
    var length_ : Nat64 = 0;
    // The identifier given to the last created node.
    var last_identifier_ : Nat64 = 0;
    // The ordering of the keys
    let key_order_ : (K, K) -> Order = key_order;

    /// Getters
    public func getRootNode() : Node<K, V> { root_node_; };
    public func getLength() : Nat64 { length_; };
    public func getKeyOrder() : (K, K) -> Order { key_order_; };

    /// Inserts a key-value pair into the map.
    ///
    /// The previous value of the key, if present, is returned.
    public func insert(key: K, value: V) : ?V {

      let root = do {

        var root = root_node_;

        // Check if the key already exists in the root.
        switch(root.getKeyIdx(key)) {
          case(#ok(idx)){
            // The key exists. Overwrite it and return the previous value.
            let (_, previous_value) = root.swapEntry(idx, (key, value));
            return ?previous_value;
          };
          case(#err(_)){
            // If the root is full, we need to introduce a new node as the root.
            //
            // NOTE: In the case where we are overwriting an existing key, then introducing
            // a new root node isn't strictly necessary. However, that's a micro-optimization
            // that adds more complexity than it's worth.
            if (root.isFull()) {
              // The root is full. Allocate a new node that will be used as the new root.
              var new_root = createNode(#Internal);
    
              // The new root has the old root as its only child.
              new_root.addChild(root_node_);
    
              // Update the root address.
              root_node_ := new_root;
    
              // Split the old (full) root. 
              splitChild(new_root, 0);
    
              new_root;
            } else {
              root;
            };
          };
        };
      };
      insertNonFull(root, key, value);
    };

    // Inserts an entry into a node that is *not full*.
    func insertNonFull(node: Node<K, V>, key: K, value: V) : ?V {
      // We're guaranteed by the caller that the provided node is not full.
      assert(not node.isFull());

      // Look for the key in the node.
      switch(node.getKeyIdx(key)){
        case(#ok(idx)){
          // The key is already in the node.
          // Overwrite it and return the previous value.
          let (_, previous_value) = node.swapEntry(idx, (key, value));

          return ?previous_value;
        };
        case(#err(idx)){
          // The key isn't in the node. `idx` is where that key should be inserted.

          switch(node.getNodeType()) {
            case(#Leaf){
              // The node is a non-full leaf.
              // Insert the entry at the proper location.
              node.insertEntry(idx, (key, value));

              // Update the length.
              length_ += 1;

              // No previous value to return.
              return null;
            };
            case(#Internal){
              // The node is an internal node.
              // Get the child that we should add the entry to.
              var child = node.getChild(idx);

              if (child.isFull()) {
                // Check if the key already exists in the child.
                switch(child.getKeyIdx(key)) {
                  case(#ok(idx)){
                    // The key exists. Overwrite it and return the previous value.
                    let (_, previous_value) = child.swapEntry(idx, (key, value));

                    return ?previous_value;
                  };
                  case(#err(_)){
                    // The child is full. Split the child.
                    splitChild(node, idx);

                    // The children have now changed. Search again for
                    // the child where we need to store the entry in.
                    let index = switch(node.getKeyIdx(key)){
                      case(#ok(i))  { i; };
                      case(#err(i)) { i; };
                    };

                    child := node.getChild(index);
                  };
                };
              };

              // The child should now be not full.
              assert(not child.isFull());

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
    func splitChild(node: Node<K, V>, full_child_idx: Nat) {
      // The node must not be full.
      assert(not node.isFull());

      // The node's child must be full.
      var full_child = node.getChild(full_child_idx);
      assert(full_child.isFull());

      // Create a sibling to this full child (which has to be the same type).
      var sibling = createNode(full_child.getNodeType());
      assert(sibling.getNodeType() == full_child.getNodeType());

      // Move the values above the median into the new sibling.
      sibling.setEntries(Utils.splitOff<Entry<K, V>>(full_child.getEntries(), Constants.B));

      if (full_child.getNodeType() == #Internal) {
        sibling.setChildren(Utils.splitOff<Node<K, V>>(full_child.getChildren(), Constants.B));
      };

      // Add sibling as a new child in the node. 
      node.insertChild(full_child_idx + 1, sibling);

      // Move the median entry into the node.
      switch(full_child.popEntry()){
        case(null){
          Debug.trap("A full child cannot be empty");
        };
        case(?median_entry){
          node.insertEntry(full_child_idx, median_entry);
        };
      };
    };

    /// Returns the value associated with the given key if it exists.
    public func get(key: K) : ?V {
      getHelper(root_node_, key);
    };

    func getHelper(node: Node<K, V>, key: K) : ?V {
      switch(node.getKeyIdx(key)){
        case(#ok(idx)) { ?node.getEntry(idx).1; };
        case(#err(idx)) {
          switch(node.getNodeType()) {
            case(#Leaf) { null; }; // Key not found.
            case(#Internal) {
              // The key isn't in the node. Look for the key in the child.
              getHelper(node.getChild(idx), key);
            };
          };
        };
      };
    };

    /// Returns `true` if the key exists in the map, `false` otherwise.
    public func containsKey(key: K) : Bool {
      Option.isSome(get(key));
    };

    /// Returns `true` if the map contains no elements.
    public func isEmpty() : Bool {
      (length_ == 0);
    };

    /// Removes a key from the map, returning the previous value at the key if it exists.
    public func remove(key: K) : ?V {
      removeHelper(root_node_, key);
    };

    // A helper method for recursively removing a key from the B-tree.
    func removeHelper(node: Node<K, V>, key: K) : ?V {

      if(node.getIdentifier() != root_node_.getIdentifier()){
        // We're guaranteed that whenever this method is called the number
        // of keys is >= `B`. Note that this is higher than the minimum required
        // in a node, which is `B - 1`, and that's because this strengthened
        // condition allows us to delete an entry in a single pass most of the
        // time without having to back up.
        assert(node.getEntries().size() >= Constants.B);
      };

      switch(node.getNodeType()) {
        case(#Leaf) {
          switch(node.getKeyIdx(key)){
            case(#ok(idx)) {
              // Case 1: The node is a leaf node and the key exists in it.
              // This is the simplest case. The key is removed from the leaf.
              let value = node.removeEntry(idx).1;
              length_ -= 1;

              if (node.getEntries().size() == 0) {
                if (node.getIdentifier() != root_node_.getIdentifier()) {
                  Debug.trap("Removal can only result in an empty leaf node if that node is the root");
                };
              };
              
              ?value;
            };
            case(_) { null; }; // Key not found.
          };
        };
        case(#Internal) {
          switch(node.getKeyIdx(key)){
            case(#ok(idx)) {
              // Case 2: The node is an internal node and the key exists in it.

              // Check if the child that precedes `key` has at least `B` keys.
              let left_child = node.getChild(idx);
              if (left_child.getEntries().size() >= Constants.B) {
                // Case 2.a: The node's left child has >= `B` keys.
                //
                //             parent
                //          [..., key, ...]
                //             /   \
                //      [left child]   [...]
                //       /      \
                //    [...]     [..., key predecessor]
                //
                // In this case, we replace `key` with the key's predecessor from the
                // left child's subtree, then we recursively delete the key's
                // predecessor for the following end result:
                //
                //             parent
                //      [..., key predecessor, ...]
                //             /   \
                //      [left child]   [...]
                //       /      \
                //    [...]      [...]

                // Recursively delete the predecessor.
                // TODO(EXC-1034): Do this in a single pass.
                let predecessor = left_child.getMax();
                ignore removeHelper(node.getChild(idx), predecessor.0);

                // Replace the `key` with its predecessor.
                let (_, old_value) = node.swapEntry(idx, predecessor);

                return ?old_value;
              };

              // Check if the child that succeeds `key` has at least `B` keys.
              let right_child = node.getChild(idx + 1);
              if (right_child.getEntries().size() >= Constants.B) {
                // Case 2.b: The node's right child has >= `B` keys.
                //
                //             parent
                //          [..., key, ...]
                //             /   \
                //           [...]   [right child]
                //              /       \
                //        [key successor, ...]   [...]
                //
                // In this case, we replace `key` with the key's successor from the
                // right child's subtree, then we recursively delete the key's
                // successor for the following end result:
                //
                //             parent
                //      [..., key successor, ...]
                //             /   \
                //          [...]   [right child]
                //               /      \
                //            [...]      [...]

                // Recursively delete the successor.
                // TODO(EXC-1034): Do this in a single pass.
                let successor = right_child.getMin();
                ignore removeHelper(node.getChild(idx + 1), successor.0);

                // Replace the `key` with its successor.
                let (_, old_value) = node.swapEntry(idx, successor);

                return ?old_value;
              };

              // Case 2.c: Both the left child and right child have B - 1 keys.
              //
              //             parent
              //          [..., key, ...]
              //             /   \
              //      [left child]   [right child]
              //
              // In this case, we merge (left child, key, right child) into a single
              // node of size 2B - 1. The result will look like this:
              //
              //             parent
              //           [...  ...]
              //             |
              //      [left child, `key`, right child] <= new child
              //
              // We then recurse on this new child to delete `key`.
              //
              // If `parent` becomes empty (which can only happen if it's the root),
              // then `parent` is deleted and `new_child` becomes the new root.
              let num_keys : Int = Constants.B - 1;
              assert(left_child.getEntries().size() == num_keys);
              assert(right_child.getEntries().size() == num_keys);

              // Merge the right child into the left child.
              let new_child = merge(left_child, right_child, node.removeEntry(idx));
              node.setChild(idx, new_child);

              // Remove the right child from the parent node.
              ignore node.removeChild(idx + 1);

              if (node.getEntries().size() == 0) {
                // Can only happen if this node is root.
                assert(node.getIdentifier() == root_node_.getIdentifier());
                assert(node.getChildrenIdentifiers() == [new_child.getIdentifier()]);

                root_node_ := new_child;
              };

              // Recursively delete the key.
              removeHelper(new_child, key);
            };
            case(#err(idx)) {
              // Case 3: The node is an internal node and the key does NOT exist in it.

              // If the key does exist in the tree, it will exist in the subtree at index
              // `idx`.
              var child = node.getChild(idx);

              if (child.getEntries().size() >= Constants.B) {
                // The child has enough nodes. Recurse to delete the `key` from the
                // `child`.
                return removeHelper(node.getChild(idx), key);
              };

              // The child has < `B` keys. Let's see if it has a sibling with >= `B` keys.
              var left_sibling = do {
                if (idx > 0) {
                  ?node.getChild(idx - 1);
                } else {
                  null;
                };
              };

              var right_sibling = do {
                if (idx + 1 < node.getChildren().size()) {
                  ?node.getChild(idx + 1);
                } else {
                  null;
                };
              };

              switch(left_sibling){
                case(null){};
                case(?left_sibling){
                  if (left_sibling.getEntries().size() >= Constants.B) {
                    // Case 3.a (left): The child has a left sibling with >= `B` keys.
                    //
                    //              [d] (parent)
                    //               /   \
                    //  (left sibling) [a, b, c]   [e, f] (child)
                    //             \
                    //             [c']
                    //
                    // In this case, we move a key down from the parent into the child
                    // and move a key from the left sibling up into the parent
                    // resulting in the following tree:
                    //
                    //              [c] (parent)
                    //               /   \
                    //     (left sibling) [a, b]   [d, e, f] (child)
                    //                /
                    //              [c']
                    //
                    // We then recurse to delete the key from the child.

                    // Remove the last entry from the left sibling.
                    switch(left_sibling.popEntry()){
                      // We tested before that the entries size is not zero, this should never happen.
                      case(null) { Debug.trap("The left sibling entries must not be empty."); };
                      case(?(left_sibling_key, left_sibling_value)){

                        // Replace the parent's entry with the one from the left sibling.
                        let (parent_key, parent_value) = node
                          .swapEntry(idx - 1, (left_sibling_key, left_sibling_value));

                        // Move the entry from the parent into the child.
                        child.insertEntry(0, (parent_key, parent_value));

                        // Move the last child from left sibling into child.
                        switch(left_sibling.popChild()) {
                          case(?last_child){
                            assert(left_sibling.getNodeType() == #Internal);
                            assert(child.getNodeType() == #Internal);

                            child.insertChild(0, last_child);
                          };
                          case(null){
                            assert(left_sibling.getNodeType() == #Leaf);
                            assert(child.getNodeType() == #Leaf);
                          };
                        };

                        return removeHelper(child, key);
                      };
                    };
                  };
                };
              };

              switch(right_sibling){
                case(null){};
                case(?right_sibling){
                  if (right_sibling.getEntries().size() >= Constants.B) {
                    // Case 3.a (right): The child has a right sibling with >= `B` keys.
                    //
                    //              [c] (parent)
                    //               /   \
                    //       (child) [a, b]   [d, e, f] (left sibling)
                    //                 /
                    //              [d']
                    //
                    // In this case, we move a key down from the parent into the child
                    // and move a key from the right sibling up into the parent
                    // resulting in the following tree:
                    //
                    //              [d] (parent)
                    //               /   \
                    //      (child) [a, b, c]   [e, f] (right sibling)
                    //              \
                    //               [d']
                    //
                    // We then recurse to delete the key from the child.

                    // Remove the first entry from the right sibling.
                    let (right_sibling_key, right_sibling_value) =
                      right_sibling.removeEntry(0);

                    // Replace the parent's entry with the one from the right sibling.
                    let parent_entry =
                      node.swapEntry(idx, (right_sibling_key, right_sibling_value));

                    // Move the entry from the parent into the child.
                    child.addEntry(parent_entry);

                    // Move the first child of right_sibling into `child`.
                    switch(right_sibling.getNodeType()) {
                      case(#Internal) {
                        assert(child.getNodeType() == #Internal);
                        child.addChild(right_sibling.removeChild(0));
                      };
                      case(#Leaf) {
                        assert(child.getNodeType() == #Leaf);
                      };
                    };

                    return removeHelper(child, key);
                  };
                };
              };

              // Case 3.b: neither siblings of the child have >= `B` keys.

              switch(left_sibling){
                case(null){};
                case(?left_sibling){
                  
                  // Merge child into left sibling.
                  let new_left_sibling = merge(left_sibling, child, node.removeEntry(idx - 1));
                  node.setChild(idx - 1, new_left_sibling);
                  
                  // Removing child from parent.
                  ignore node.removeChild(idx);

                  if (node.getEntries().size() == 0) {

                    if (node.getIdentifier() == root_node_.getIdentifier()) {
                      // Update the root.
                      root_node_ := new_left_sibling;
                    };
                  };

                  return removeHelper(new_left_sibling, key);
                };
              };

              switch(right_sibling){
                case(null){};
                case(?right_sibling){
                  
                  // Merge right sibling into child.
                  let new_child = merge(child, right_sibling, node.removeEntry(idx));
                  node.setChild(idx, new_child);

                  // Removing child from parent.
                  ignore node.removeChild(idx + 1);

                  if (node.getEntries().size() == 0) {

                    if (node.getIdentifier() == root_node_.getIdentifier()) {
                      // Update the root.
                      root_node_ := new_child;
                    };
                  };

                  return removeHelper(new_child, key);
                };
              };

              Debug.trap("At least one of the siblings must exist.");
            };
          };
        };
      };
    };

    // Returns an iterator over the entries of the map, sorted by key.
    public func iter() : Iter<K, V> {
      Iter.new<K, V>(self);
    };

    /// Returns an iterator over the entries in the map where keys are greater than or equal
    /// to `lower_bound`, and inferior than or equal to `upper_bound`.
    public func range(lower_bound: K, upper_bound: K) : Iter<K, V> {
      
      var node = root_node_;
      let cursors = Buffer.Buffer<Cursor<K, V>>(0);

      loop {
        let idx = switch(node.getKeyIdx(lower_bound)){
          case(#err(idx)) { idx; };
          case(#ok(idx)) { idx; };
        };

        // If the key is the lower bound, then `idx` would return its
        // location. Otherwise, `idx` is the location of the next slightly
        // greater key.

        // If key is lower than or equal to the upper bound, then add a cursor starting from its index.
        if (idx < node.getEntries().size() and not(Order.isGreater(key_order_(node.getEntry(idx).0, upper_bound)))){
          cursors.add({
            node;
            next = #Entry(Nat64.fromNat(idx));
          });
        };

        // Load the next child of the node to visit if it exists.
        switch(node.getNodeType()) {
          case(#Internal) {
            // Note that loading a child node cannot fail since
            // len(children) = len(entries) + 1
            node := node.getChild(idx);
          };
          case(#Leaf) { 
            // Leaf node. Return an iterator with the found cursors.
            return Iter.newWithBounds(self, cursors.toArray(), lower_bound, upper_bound);
          };
        };
      };

    };

    // Merges one node (`higher`) into another node (`lower`), along with a median entry.
    //
    // Example (values are not included for brevity):
    //
    // Input:
    //   lower: [1, 2, 3]
    //   higher: [5, 6, 7]
    //   Median: 4
    //
    // Output:
    //   [1, 2, 3, 4, 5, 6, 7] (stored in the `lower` node)
    func merge(lower: Node<K, V>, higher: Node<K, V>, median: Entry<K, V>) : Node<K, V> {
      let original_size = higher.getChildren().size();

      assert(lower.getNodeType() == higher.getNodeType());
      assert(lower.getEntries().size() != 0);
      assert(higher.getEntries().size() != 0);
      assert(Order.isLess(key_order_(lower.getEntry(0).0, higher.getEntry(0).0)));

      lower.addEntry(median);

      lower.appendEntries(higher.getEntries());

      // Move the children (if any exist).
      lower.appendChildren(higher.getChildren());

      lower;
    };

    func createNode(node_type: NodeType) : Node<K, V> {
      last_identifier_ := last_identifier_ + 1;
      Node.Node(key_order_, node_type, last_identifier_);
    };

  };

};