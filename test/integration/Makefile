default:
	dfx stop
	dfx start --clean --background
	dfx deploy test --argument='(record {max_key_size=32; max_value_size=128})'
	ic-repl test.sh
	node test.js