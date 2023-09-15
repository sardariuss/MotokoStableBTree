#!/usr/local/bin/ic-repl

function install(wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/multipleBTrees/multipleBTrees.did";
  let id = call ic.provisional_create_canister_with_cycles(record { settings = null; amount = null; });
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record{});
      wasm_module = wasm;
      mode = variant { install };
      canister_id = id.canister_id;
    }
  );
  id.canister_id
};

function upgrade(canister_id, wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/multipleBTrees/multipleBTrees.did";
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record{});
      wasm_module = wasm;
      mode = variant { upgrade };
      canister_id = canister_id;
    }
  );
};

function reinstall(canister_id, wasm) {
  import interface = "2vxsx-fae" as ".dfx/local/canisters/multipleBTrees/multipleBTrees.did";
  call ic.install_code(
    record {
      arg = encode interface.__init_args(record{});
      wasm_module = wasm;
      mode = variant { reinstall };
      canister_id = canister_id;
    }
  );
};

// Create the canister
let multiple_btrees = install(file(".dfx/local/canisters/multipleBTrees/multipleBTrees.wasm"));

// Create a first BTree
let b1 = call multiple_btrees.spawnBTree();
assert b1 == (16 : nat);
call multiple_btrees.getLength(b1);
assert _ == (0 : nat64);
call multiple_btrees.insert(b1, 12345, "hello");
assert _ == variant { ok = null : opt record{} };
call multiple_btrees.getLength(b1);
assert _ == (1 : nat64);
call multiple_btrees.get(b1, 12345);
assert _ == opt("hello" : text);

// Create a second BTree
let b2 = call multiple_btrees.spawnBTree();
call multiple_btrees.getLength(b2);
assert _ == (0 : nat64);
call multiple_btrees.get(b2, 12345);
assert _ == (null : opt record{});
call multiple_btrees.insert(b2, 67890, "hi");
call multiple_btrees.insert(b2, 45678, "ola");
call multiple_btrees.insert(b2, 34567, "salut");
assert _ == variant { ok = null : opt record{} };
call multiple_btrees.getLength(b2);
assert _ == (3 : nat64);
call multiple_btrees.get(b2, 67890);
assert _ == opt("hi" : text);
call multiple_btrees.get(b2, 45678);
assert _ == opt("ola" : text);
call multiple_btrees.get(b2, 34567);
assert _ == opt("salut" : text);

// Both BTrees shall be preserved after an upgrade
upgrade(multiple_btrees, file(".dfx/local/canisters/multipleBTrees/multipleBTrees.wasm"));
call multiple_btrees.getLength(b1);
assert _ == (1 : nat64);
call multiple_btrees.get(b1, 12345);
assert _ == opt("hello" : text);
call multiple_btrees.getLength(b2);
assert _ == (3 : nat64);
call multiple_btrees.get(b2, 67890);
assert _ == opt("hi" : text);
call multiple_btrees.get(b2, 45678);
assert _ == opt("ola" : text);
call multiple_btrees.get(b2, 34567);
assert _ == opt("salut" : text);

// Both BTrees shall be emptied after a reinstall
// The stable regions are cleared during the reinstall, it is not possible to do that test, the "handles" on the regions are lost
