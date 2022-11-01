import TestIter "testIter";
import TestAllocator "testAllocator";
import TestBTreeMap "testBTreeMap";
import TestMemoryManager "testMemoryManager";

import Suite "mo:matchers/Suite";

Suite.run(TestAllocator.TestAllocator().getSuite());
Suite.run(TestBTreeMap.TestBTreeMap().getSuite());
Suite.run(TestIter.TestIter().getSuite());
Suite.run(TestMemoryManager.TestMemoryManager().getSuite());
