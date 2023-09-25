#!/usr/local/bin/ic-repl

function install(wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/singleBTree/singleBTree.did";
  let id = call ic.provisional_create_canister_with_cycles(record { settings = null; amount = null; });
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record {});
      wasm_module = wasm;
      mode = variant { install };
      canister_id = id.canister_id;
    }
  );
  id.canister_id
};

function upgrade(canister_id, wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/singleBTree/singleBTree.did";
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record {});
      wasm_module = wasm;
      mode = variant { upgrade };
      canister_id = canister_id;
    }
  );
};

function reinstall(canister_id, wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/singleBTree/singleBTree.did";
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record {});
      wasm_module = wasm;
      mode = variant { reinstall };
      canister_id = canister_id;
    }
  );
};

// Create a BTree
let btree_canister = install(file(".dfx/local/canisters/singleBTree/singleBTree.wasm"));
// Verify it is empty
call btree_canister.size();
assert _ == (0 : nat);
// Insert a pair of key/value
call btree_canister.put(12345, "hello");
// Verify the Btree contains the pair of key/value
call btree_canister.size();
assert _ == (1 : nat);
call btree_canister.get(12345);
assert _ == opt("hello" : text);

// The BTree shall be preserved after an upgrade
upgrade(btree_canister, file(".dfx/local/canisters/singleBTree/singleBTree.wasm"));
call btree_canister.size();
assert _ == (1 : nat);
call btree_canister.get(12345);
assert _ == opt("hello" : text);

// The BTree shall be empty after a reinstall
reinstall(btree_canister, file(".dfx/local/canisters/singleBTree/singleBTree.wasm"));
call btree_canister.size();
assert _ == (0 : nat);
call btree_canister.get(12345);
assert _ == (null : opt record{});