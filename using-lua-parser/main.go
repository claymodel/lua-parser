package main

import (
    "fmt"

    "github.com/claymodel/lua-parser"
)

func main() {
    l := lua.NewState()
    defer l.Close()

    if err := l.DoFile("hello.lua"); err != nil {
        panic(err)
    }

    a := l.GetGlobal("a")
    fmt.Printf("a=%v\n", a)

    b := l.GetGlobal("b").(*lua.LTable)
    b.ForEach(func(key, value lua.LValue) {
        fmt.Printf("b.%v=%v\n", key, value)
    })
}

