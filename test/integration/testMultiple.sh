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

// Create a first BTree (id = 0)
call multiple_btrees.size(0);
assert _ == (0 : nat);
call multiple_btrees.put(0, 12345, "hello");
assert _ == (null : opt text);
call multiple_btrees.size(0);
assert _ == (1 : nat);
call multiple_btrees.get(0, 12345);
assert _ == opt("hello" : text);

// Create a second BTree (id = 1)
call multiple_btrees.size(1);
assert _ == (0 : nat);
call multiple_btrees.get(1, 12345);
assert _ == (null : opt text);
call multiple_btrees.put(1, 67890, "hi");
call multiple_btrees.put(1, 45678, "ola");
call multiple_btrees.put(1, 34567, "salut");
call multiple_btrees.size(1);
assert _ == (3 : nat);
call multiple_btrees.get(1, 67890);
assert _ == opt("hi" : text);
call multiple_btrees.get(1, 45678);
assert _ == opt("ola" : text);
call multiple_btrees.get(1, 34567);
assert _ == opt("salut" : text);

// Both BTrees shall be preserved after an upgrade
upgrade(multiple_btrees, file(".dfx/local/canisters/multipleBTrees/multipleBTrees.wasm"));
call multiple_btrees.size(0);
assert _ == (1 : nat);
call multiple_btrees.get(0, 12345);
assert _ == opt("hello" : text);
call multiple_btrees.size(1);
assert _ == (3 : nat);
call multiple_btrees.get(1, 67890);
assert _ == opt("hi" : text);
call multiple_btrees.get(1, 45678);
assert _ == opt("ola" : text);
call multiple_btrees.get(1, 34567);
assert _ == opt("salut" : text);

// Both BTrees shall be emptied after a reinstall
reinstall(multiple_btrees, file(".dfx/local/canisters/multipleBTrees/multipleBTrees.wasm"));
call multiple_btrees.size(0);
assert _ == (0 : nat);
call multiple_btrees.get(0, 12345);
assert _ == (null : opt text);
call multiple_btrees.size(1);
assert _ == (0 : nat);
call multiple_btrees.get(1, 67890);
assert _ == (null : opt text);
call multiple_btrees.get(1, 45678);
assert _ == (null : opt text);
call multiple_btrees.get(1, 34567);
assert _ == (null : opt text);
