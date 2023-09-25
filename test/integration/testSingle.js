import { idlFactory, canisterId } from "./src/declarations/singleBTree/index.js";

import { HttpAgent, Actor }       from "@dfinity/agent";
import fetch                      from "isomorphic-fetch";
import { test }                   from "tape";

const agent = new HttpAgent({
  host: "http://localhost:4943/",
  fetch: fetch
});

agent.fetchRootKey().catch((err) => {
  console.warn("Unable to fetch root key. Check to ensure that your local replica is running");
  console.error(err);
});

const singleBTree = Actor.createActor(idlFactory, {
  agent: agent,
  canisterId: canisterId
});

const NUM_INSERTIONS = 5000;

const MAX_BTREE_ITERATIONS = 1000;

const NUM_CALLS = NUM_INSERTIONS / MAX_BTREE_ITERATIONS;

const btree_insert_test = async (t, keys) => {
  // Verify the btree is empty
  if (await singleBTree.size() != 0n){
    throw new FatalError("The btree is not empty");
  }

  const entries = keys.map(key => [key, key.toString()]);
  const unique_keys = [...new Set(keys)];

  var insert_result = true;

  // Insert entries in the btree
  for (var i=0; i<NUM_CALLS; i++){
    const lower_bound = i * MAX_BTREE_ITERATIONS;
    const upper_bound = (i + 1) * MAX_BTREE_ITERATIONS;
    const sub_entries = entries.filter((value, index) => index >= lower_bound && index < upper_bound);
    insert_result &= ((await singleBTree.insertMany(sub_entries)).err === undefined);
  }
  
  // Verify the insertions worked
  t.ok(insert_result);
  
  // Verify the length of the btree
  t.equal(await singleBTree.size(), BigInt(unique_keys.length));

  var get_result = true;

  // Retrieve entries in the btree
  for (var i=0; i<NUM_CALLS; i++){
    const lower_bound = i * MAX_BTREE_ITERATIONS;
    const upper_bound = (i + 1) * MAX_BTREE_ITERATIONS;
    const sub_keys = unique_keys.filter((value, index) => index >= lower_bound && index < upper_bound);
    // Use join to compare array's content
    get_result &= ((await singleBTree.getMany(sub_keys)).join("") == sub_keys.map(key => key.toString()).join(""));
  }

  // Verify retrieving each value worked
  t.ok(get_result);

  // Empty the btree
  await singleBTree.clear();
};

test('random_insertions', async function (t) {
  // Create NUM_INSERTIONS random entries
  let keys = [];
  for (var i=0; i<NUM_INSERTIONS; i++){
    let power = Math.trunc(Math.random() * 32);
    let random_nat32 = Math.trunc(Math.random() * 2 ** power);
    keys.push(random_nat32);
  }
  await btree_insert_test(t, keys);
});

test('increasing_insertions', async function (t) {
  // Insert NUM_INSERTIONS increasing entries
  let keys = [];
  for (var i=0; i<NUM_INSERTIONS; i++){
    keys.push(i);
  };
  await btree_insert_test(t, keys);
});

test('decreasing_insertions', async function (t) {
  // Insert NUM_INSERTIONS decreasing entries
  let keys = [];
  for (var i=(NUM_INSERTIONS-1); i >= 0; i--){
    keys.push(i);
  };
  await btree_insert_test(t, keys);
});