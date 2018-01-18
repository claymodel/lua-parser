# lua-parser
lua inerpreter in Golang

```
export GOPATH=~/src
export GOBIN=$GOPATH/bin
go get github.com/claymodel/lua-parser
```

Load the Lua files as follows,

```
l := lua.NewState()
```

and finally execute

```
l.DoFile("hello.lua")
```

For better understanding use the example in the folder
```
./using-lua-parser/
```
