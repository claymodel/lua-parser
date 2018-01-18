.PHONY: build test glua

build:
	./_tools/go-inline *.go && go fmt . &&  go build

glua: *.go patterns/*.go cmd/glua/glua.go
	./_tools/go-inline *.go && go fmt . && go build cmd/glua/glua.go

test:
	./_tools/go-inline *.go && go fmt . &&  go test

