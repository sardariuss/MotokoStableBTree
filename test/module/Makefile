default:
	$(shell dfx cache show)/moc $(shell vessel sources) -wasi-system-api -o suite.wasm suite.mo && wasmtime suite.wasm
	rm -f suite.wasm
