// RUN: %boogie -noinfer -useArrayTheory "%s" > "%t"
// RUN: %diff "%s.expect" "%t"
function {:builtin "MapConst"} MapConstBool(bool) : [int]bool;

type lmap;
function {:linear "mem"} dom(lmap): [int]bool;
function map(lmap): [int]int;
function cons([int]bool, [int]int) : lmap;
axiom (forall x: [int]bool, y: [int]int :: {cons(x,y)} dom(cons(x, y)) == x && map(cons(x,y)) == y);
axiom (forall x: lmap :: {dom(x)} {map(x)} cons(dom(x), map(x)) == x);

function Empty(m:[int]int): lmap;
axiom (forall m: [int]int :: Empty(m) == cons(MapConstBool(false), m));

function Add(x: lmap, i: int): lmap;
axiom (forall x: lmap, i: int :: dom(Add(x, i)) == dom(x)[i:=true] && map(Add(x, i)) == map(x));

function Remove(x: lmap, i: int): lmap;
axiom (forall x: lmap, i: int :: dom(Remove(x, i)) == dom(x)[i:=false] && map(Remove(x, i)) == map(x));

function {:inline} PoolInv(unallocated:[int]bool, pool: lmap) : (bool)
{
    (forall x: int :: unallocated[x] ==> dom(pool)[x])
}

procedure {:yields} {:layer 2} Main()
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
{
   var {:layer 1} {:linear "mem"} l: lmap;
   var i: int;
   par Yield() | Dummy();
   while (*)
   invariant {:layer 1} PoolInv(unallocated, pool);
   {
      call  l, i := Alloc();
      async call Thread(l, i);
      par Yield() | Dummy();
   }
   par Yield() | Dummy();
}

procedure {:yields} {:layer 2} Thread({:layer 1} {:linear_in "mem"} local_in: lmap, i: int)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
requires {:layer 1} dom(local_in)[i] && map(local_in)[i] == mem[i];
requires {:layer 2} dom(local_in)[i];
{
    var y, o: int;
    var {:layer 1} {:linear "mem"} local: lmap;
    var {:layer 1} {:linear "mem"} l: lmap;

    par YieldMem(local_in, i) | Dummy();
    call local := Write(local_in, i, 42);
    call o := Read(local, i);
    assert {:layer 2} o == 42;
    while (*)
    invariant {:layer 1} PoolInv(unallocated, pool);
    {
        call l, y := Alloc();
        call l := Write(l, y, 42);
	call o := Read(l, y);
	assert {:layer 2} o == 42;
        call Free(l, y);
	par Yield() | Dummy();
    }
    par Yield() | Dummy();
}

procedure {:yields} {:layer 1,2} Alloc() returns ({:layer 1} {:linear "mem"} l: lmap, i: int)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
ensures {:right} |{ var m:[int]int; A: assume dom(pool)[i]; pool := Remove(pool, i); l := Add(Empty(m), i); return true; }|;
{
    call Yield();
    call i := PickAddr();
    call l := AllocLinear(i);
    call YieldMem(l, i);
}

procedure {:yields} {:layer 1,2} Free({:layer 1} {:linear_in "mem"} l: lmap, i: int)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
requires {:layer 1} dom(l)[i];
ensures {:left} |{ A: assert dom(l)[i]; pool := Add(pool, i); return true; }|;
{
    call Yield();
    call FreeLinear(l, i);
    call ReturnAddr(i);
    call Yield();
}

procedure {:yields} {:layer 1,2} Read({:layer 1} {:linear "mem"} l: lmap, i: int) returns (o: int)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
requires {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
ensures {:both} |{ A: assert dom(l)[i]; o := map(l)[i]; return true; }|;
{
    call YieldMem(l, i);
    call o := ReadLow(i);
    call YieldMem(l, i);
}

procedure {:yields} {:layer 1,2} Write({:layer 1} {:linear_in "mem"} l: lmap, i: int, o: int) returns ({:layer 1} {:linear "mem"} l': lmap)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
requires {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
ensures  {:layer 1} dom(l')[i] && map(l')[i] == mem[i];
ensures {:both} |{ A: assert dom(l)[i]; l' := cons(dom(l), map(l)[i := o]); return true; }|;
{
    call YieldMem(l, i);
    call WriteLow(i, o);
    call l' := WriteLinear(l, i, o);
    call YieldMem(l', i);
}

procedure {:layer 1} AllocLinear(i: int) returns ({:linear "mem"} l: lmap);
modifies pool;
requires dom(pool)[i];
ensures pool == Remove(old(pool), i) && l == Add(Empty(mem), i);

procedure {:layer 1} FreeLinear({:linear_in "mem"} l: lmap, i: int);
modifies pool;
requires dom(l)[i];
ensures pool == Add(old(pool), i);

procedure {:layer 1} WriteLinear({:layer 1} {:linear_in "mem"} l: lmap, i: int, o: int) returns ({:layer 1} {:linear "mem"} l': lmap);
requires dom(l)[i];
ensures l' == cons(dom(l), map(l)[i := o]);

procedure {:yields} {:layer 1} Yield()
requires {:layer 1} PoolInv(unallocated, pool);
ensures {:layer 1} PoolInv(unallocated, pool);
{
    yield;
    assert {:layer 1} PoolInv(unallocated, pool);
}

procedure {:yields} {:layer 1} YieldMem({:layer 1} {:linear "mem"} l: lmap, i: int)
requires {:layer 1} PoolInv(unallocated, pool);
ensures  {:layer 1} PoolInv(unallocated, pool);
requires {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
ensures {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
{
    yield;
    assert {:layer 1} PoolInv(unallocated, pool);
    assert {:layer 1} dom(l)[i] && map(l)[i] == mem[i];
}

procedure {:yields} {:layer 2} Dummy()
{
    yield;
}

var {:layer 1, 2} {:linear "mem"} pool: lmap;
var {:layer 0, 1} mem:[int]int;
var {:layer 0, 1} unallocated:[int]bool;

procedure {:yields} {:layer 0, 1} ReadLow(i: int) returns (o: int);
ensures {:atomic} |{ A: o := mem[i]; return true; }|;

procedure {:yields} {:layer 0, 1} WriteLow(i: int, o: int);
ensures {:atomic} |{ A: mem[i] := o; return true; }|;

procedure {:yields} {:layer 0, 1} PickAddr() returns (i: int);
ensures {:atomic} |{ A: assume unallocated[i]; unallocated[i] := false; return true; }|;

procedure {:yields} {:layer 0, 1} ReturnAddr(i: int);
ensures {:atomic} |{ A: unallocated[i] := true; return true; }|;
