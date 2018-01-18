%{
package parsing

import (
  "github.com/claymodel/lua-parser/utiils"
)
%}
%type<stmts> chunk
%type<stmts> chunk1
%type<stmts> block
%type<stmt>  stat
%type<stmts> elseifs
%type<stmt>  laststat
%type<funcname> funcname
%type<funcname> funcname1
%type<exprlist> varlist
%type<expr> var
%type<namelist> namelist
%type<exprlist> exprlist
%type<expr> expr
%type<expr> string
%type<expr> prefixexp
%type<expr> functioncall
%type<expr> afunctioncall
%type<exprlist> args
%type<expr> function
%type<funcexpr> funcbody
%type<parlist> parlist
%type<expr> tableconstructor
%type<fieldlist> fieldlist
%type<field> field
%type<fieldsep> fieldsep

%union {
  token  utils.Token

  stmts    []utils.Stmt
  stmt     utils.Stmt

  funcname *utils.FuncName
  funcexpr *utils.FunctionExpr

  exprlist []utils.Expr
  expr   utils.Expr

  fieldlist []*utils.Field
  field     *utils.Field
  fieldsep  string

  namelist []string
  parlist  *utils.ParList
}

/* Reserved words */
%token<token> TAnd TBreak TDo TElse TElseIf TEnd TFalse TFor TFunction TIf TIn TLocal TNil TNot TOr TReturn TRepeat TThen TTrue TUntil TWhile 

/* Literals */
%token<token> TEqeq TNeq TLte TGte T2Comma T3Comma TIdent TNumber TString '{' '('

/* Operators */
%left TOr
%left TAnd
%left '>' '<' TGte TLte TEqeq TNeq
%right T2Comma
%left '+' '-'
%left '*' '/' '%'
%right UNARY /* not # -(unary) */
%right '^'

%%

chunk: 
        chunk1 {
            $$ = $1
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        } |
        chunk1 laststat {
            $$ = append($1, $2)
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        } | 
        chunk1 laststat ';' {
            $$ = append($1, $2)
            if l, ok := yylex.(*Lexer); ok {
                l.Stmts = $$
            }
        }

chunk1: 
        {
            $$ = []utils.Stmt{}
        } |
        chunk1 stat {
            $$ = append($1, $2)
        } | 
        chunk1 ';' {
            $$ = $1
        }

block: 
        chunk {
            $$ = $1
        }

stat:
        varlist '=' exprlist {
            $$ = &utils.AssignStmt{Lhs: $1, Rhs: $3}
            $$.SetLine($1[0].Line())
        } |
        /* 'stat = functioncal' causes a reduce/reduce conflict */
        prefixexp {
            if _, ok := $1.(*utils.FuncCallExpr); !ok {
               yylex.(*Lexer).Error("parse error")
            } else {
              $$ = &utils.FuncCallStmt{Expr: $1}
              $$.SetLine($1.Line())
            }
        } |
        TDo block TEnd {
            $$ = &utils.DoBlockStmt{Stmts: $2}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($3.Pos.Line)
        } |
        TWhile expr TDo block TEnd {
            $$ = &utils.WhileStmt{Condition: $2, Stmts: $4}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($5.Pos.Line)
        } |
        TRepeat block TUntil expr {
            $$ = &utils.RepeatStmt{Condition: $4, Stmts: $2}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.Line())
        } |
        TIf expr TThen block elseifs TEnd {
            $$ = &utils.IfStmt{Condition: $2, Then: $4}
            cur := $$
            for _, elseif := range $5 {
                cur.(*utils.IfStmt).Else = []utils.Stmt{elseif}
                cur = elseif
            }
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($6.Pos.Line)
        } |
        TIf expr TThen block elseifs TElse block TEnd {
            $$ = &utils.IfStmt{Condition: $2, Then: $4}
            cur := $$
            for _, elseif := range $5 {
                cur.(*utils.IfStmt).Else = []utils.Stmt{elseif}
                cur = elseif
            }
            cur.(*utils.IfStmt).Else = $7
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($8.Pos.Line)
        } |
        TFor TIdent '=' expr ',' expr TDo block TEnd {
            $$ = &utils.NumberForStmt{Name: $2.Str, Init: $4, Limit: $6, Stmts: $8}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($9.Pos.Line)
        } |
        TFor TIdent '=' expr ',' expr ',' expr TDo block TEnd {
            $$ = &utils.NumberForStmt{Name: $2.Str, Init: $4, Limit: $6, Step:$8, Stmts: $10}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($11.Pos.Line)
        } |
        TFor namelist TIn exprlist TDo block TEnd {
            $$ = &utils.GenericForStmt{Names:$2, Exprs:$4, Stmts: $6}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($7.Pos.Line)
        } |
        TFunction funcname funcbody {
            $$ = &utils.FuncDefStmt{Name: $2, Func: $3}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($3.LastLine())
        } |
        TLocal TFunction TIdent funcbody {
            $$ = &utils.LocalAssignStmt{Names:[]string{$3.Str}, Exprs: []utils.Expr{$4}}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.LastLine())
        } | 
        TLocal namelist '=' exprlist {
            $$ = &utils.LocalAssignStmt{Names: $2, Exprs:$4}
            $$.SetLine($1.Pos.Line)
        } |
        TLocal namelist {
            $$ = &utils.LocalAssignStmt{Names: $2, Exprs:[]utils.Expr{}}
            $$.SetLine($1.Pos.Line)
        }

elseifs: 
        {
            $$ = []utils.Stmt{}
        } | 
        elseifs TElseIf expr TThen block {
            $$ = append($1, &utils.IfStmt{Condition: $3, Then: $5})
            $$[len($$)-1].SetLine($2.Pos.Line)
        }

laststat:
        TReturn {
            $$ = &utils.ReturnStmt{Exprs:nil}
            $$.SetLine($1.Pos.Line)
        } |
        TReturn exprlist {
            $$ = &utils.ReturnStmt{Exprs:$2}
            $$.SetLine($1.Pos.Line)
        } |
        TBreak  {
            $$ = &utils.BreakStmt{}
            $$.SetLine($1.Pos.Line)
        }

funcname: 
        funcname1 {
            $$ = $1
        } |
        funcname1 ':' TIdent {
            $$ = &utils.FuncName{Func:nil, Receiver:$1.Func, Method: $3.Str}
        }

funcname1:
        TIdent {
            $$ = &utils.FuncName{Func: &utils.IdentExpr{Value:$1.Str}}
            $$.Func.SetLine($1.Pos.Line)
        } | 
        funcname1 '.' TIdent {
            key:= &utils.StringExpr{Value:$3.Str}
            key.SetLine($3.Pos.Line)
            fn := &utils.AttrGetExpr{Object: $1.Func, Key: key}
            fn.SetLine($3.Pos.Line)
            $$ = &utils.FuncName{Func: fn}
        }

varlist:
        var {
            $$ = []utils.Expr{$1}
        } | 
        varlist ',' var {
            $$ = append($1, $3)
        }

var:
        TIdent {
            $$ = &utils.IdentExpr{Value:$1.Str}
            $$.SetLine($1.Pos.Line)
        } |
        prefixexp '[' expr ']' {
            $$ = &utils.AttrGetExpr{Object: $1, Key: $3}
            $$.SetLine($1.Line())
        } | 
        prefixexp '.' TIdent {
            key := &utils.StringExpr{Value:$3.Str}
            key.SetLine($3.Pos.Line)
            $$ = &utils.AttrGetExpr{Object: $1, Key: key}
            $$.SetLine($1.Line())
        }

namelist:
        TIdent {
            $$ = []string{$1.Str}
        } | 
        namelist ','  TIdent {
            $$ = append($1, $3.Str)
        }

exprlist:
        expr {
            $$ = []utils.Expr{$1}
        } |
        exprlist ',' expr {
            $$ = append($1, $3)
        }

expr:
        TNil {
            $$ = &utils.NilExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TFalse {
            $$ = &utils.FalseExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TTrue {
            $$ = &utils.TrueExpr{}
            $$.SetLine($1.Pos.Line)
        } | 
        TNumber {
            $$ = &utils.NumberExpr{Value: $1.Str}
            $$.SetLine($1.Pos.Line)
        } | 
        T3Comma {
            $$ = &utils.Comma3Expr{}
            $$.SetLine($1.Pos.Line)
        } |
        function {
            $$ = $1
        } | 
        prefixexp {
            $$ = $1
        } |
        string {
            $$ = $1
        } |
        tableconstructor {
            $$ = $1
        } |
        expr TOr expr {
            $$ = &utils.LogicalOpExpr{Lhs: $1, Operator: "or", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TAnd expr {
            $$ = &utils.LogicalOpExpr{Lhs: $1, Operator: "and", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '>' expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: ">", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '<' expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: "<", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TGte expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: ">=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TLte expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: "<=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TEqeq expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: "==", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr TNeq expr {
            $$ = &utils.RelationalOpExpr{Lhs: $1, Operator: "~=", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr T2Comma expr {
            $$ = &utils.StringConcatOpExpr{Lhs: $1, Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '+' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "+", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '-' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "-", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '*' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "*", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '/' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "/", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '%' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "%", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        expr '^' expr {
            $$ = &utils.ArithmeticOpExpr{Lhs: $1, Operator: "^", Rhs: $3}
            $$.SetLine($1.Line())
        } |
        '-' expr %prec UNARY {
            $$ = &utils.UnaryMinusOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        } |
        TNot expr %prec UNARY {
            $$ = &utils.UnaryNotOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        } |
        '#' expr %prec UNARY {
            $$ = &utils.UnaryLenOpExpr{Expr: $2}
            $$.SetLine($2.Line())
        }

string: 
        TString {
            $$ = &utils.StringExpr{Value: $1.Str}
            $$.SetLine($1.Pos.Line)
        } 

prefixexp:
        var {
            $$ = $1
        } |
        afunctioncall {
            $$ = $1
        } |
        functioncall {
            $$ = $1
        } |
        '(' expr ')' {
            $$ = $2
            $$.SetLine($1.Pos.Line)
        }

afunctioncall:
        '(' functioncall ')' {
            $2.(*utils.FuncCallExpr).AdjustRet = true
            $$ = $2
        }

functioncall:
        prefixexp args {
            $$ = &utils.FuncCallExpr{Func: $1, Args: $2}
            $$.SetLine($1.Line())
        } |
        prefixexp ':' TIdent args {
            $$ = &utils.FuncCallExpr{Method: $3.Str, Receiver: $1, Args: $4}
            $$.SetLine($1.Line())
        }

args:
        '(' ')' {
            if yylex.(*Lexer).PNewLine {
               yylex.(*Lexer).TokenError($1, "ambiguous syntax (function call x new statement)")
            }
            $$ = []utils.Expr{}
        } |
        '(' exprlist ')' {
            if yylex.(*Lexer).PNewLine {
               yylex.(*Lexer).TokenError($1, "ambiguous syntax (function call x new statement)")
            }
            $$ = $2
        } |
        tableconstructor {
            $$ = []utils.Expr{$1}
        } | 
        string {
            $$ = []utils.Expr{$1}
        }

function:
        TFunction funcbody {
            $$ = &utils.FunctionExpr{ParList:$2.ParList, Stmts: $2.Stmts}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($2.LastLine())
        }

funcbody:
        '(' parlist ')' block TEnd {
            $$ = &utils.FunctionExpr{ParList: $2, Stmts: $4}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($5.Pos.Line)
        } | 
        '(' ')' block TEnd {
            $$ = &utils.FunctionExpr{ParList: &utils.ParList{HasVargs: false, Names: []string{}}, Stmts: $3}
            $$.SetLine($1.Pos.Line)
            $$.SetLastLine($4.Pos.Line)
        }

parlist:
        T3Comma {
            $$ = &utils.ParList{HasVargs: true, Names: []string{}}
        } | 
        namelist {
          $$ = &utils.ParList{HasVargs: false, Names: []string{}}
          $$.Names = append($$.Names, $1...)
        } | 
        namelist ',' T3Comma {
          $$ = &utils.ParList{HasVargs: true, Names: []string{}}
          $$.Names = append($$.Names, $1...)
        }


tableconstructor:
        '{' '}' {
            $$ = &utils.TableExpr{Fields: []*utils.Field{}}
            $$.SetLine($1.Pos.Line)
        } |
        '{' fieldlist '}' {
            $$ = &utils.TableExpr{Fields: $2}
            $$.SetLine($1.Pos.Line)
        }


fieldlist:
        field {
            $$ = []*utils.Field{$1}
        } | 
        fieldlist fieldsep field {
            $$ = append($1, $3)
        } | 
        fieldlist fieldsep {
            $$ = $1
        }

field:
        TIdent '=' expr {
            $$ = &utils.Field{Key: &utils.StringExpr{Value:$1.Str}, Value: $3}
            $$.Key.SetLine($1.Pos.Line)
        } | 
        '[' expr ']' '=' expr {
            $$ = &utils.Field{Key: $2, Value: $5}
        } |
        expr {
            $$ = &utils.Field{Value: $1}
        }

fieldsep:
        ',' {
            $$ = ","
        } | 
        ';' {
            $$ = ";"
        }

%%

func TokenName(c int) string {
	if c >= TAnd && c-TAnd < len(yyToknames) {
		if yyToknames[c-TAnd] != "" {
			return yyToknames[c-TAnd]
		}
	}
    return string([]byte{byte(c)})
}

