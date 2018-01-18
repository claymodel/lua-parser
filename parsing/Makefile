all : parse.go

parse.go : parse.go.y
	goyacc -o $@ parse.go.y; [ -f y.output ] && ( rm -f y.output )
