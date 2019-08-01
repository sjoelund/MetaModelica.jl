/#
 # This file is part of OpenModelica.
 #
 # Copyright (c) 1998-Current year, Open Source Modelica Consortium (OSMC),
 # c/o Linköpings universitet, Department of Computer and Information Science,
 # SE-58183 Linköping, Sweden.
 #
 # All rights reserved.
 #
 # THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
 # THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 # ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 # RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
 # ACCORDING TO RECIPIENTS CHOICE.
 #'
 # The OpenModelica software and the Open Source Modelica
 # Consortium (OSMC) Public License (OSMC-PL) are obtained
 # from OSMC, either from the above address,
 # from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 # http://www.openmodelica.org, and in the OpenModelica distribution.
 # GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 #
 # This program is distributed WITHOUT ANY WARRANTY; without
 # even the implied warranty of  MERCHANTABILITY or FITNESS
 # FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 # IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 #
 # See the full OSMC Public License conditions for more details.
 #
 #/

module ListDef

#=!!! Observe we only ever create Nil{Any} !!!=#
struct Nil{T} end

struct Cons{T}
  head::T
  tail::Union{Nil, Cons{T}}
end

List{T} = Union{Nil{T}, Cons{T}, Nil}
List() = Nil{Any}()
Nil() = List()

#= 
  These promotion rules might seem a bit odd. Still it is the most efficient way I found of casting immutable lists
  If someone see a better alternative to this approach please fix me :). Basically I create a new list in O(N) * C time 
  with the type we cast to. Also, do not create new conversion strategies without measuring performance as they will call themselves 
  recursivly 
+=#

Base.convert(::Type{List{S}}, x::List{T}) where {S, T <: S} = let
  List(S, promote(x))
end

Base.convert(::Type{T}, a::List) where {T <: List} = let
  a isa T ? a : List(eltype(T), promote(a))
end

#= Identity cases =#
Base.convert(::Type{List{T}}, x::List{T}) where {T} = x
Base.convert(::Type{List}, x::List) = x
Base.convert(::Type{List}, x::Nil) = x

Base.promote_rule(a::Type{List{T}}, b::Type{List{S}}) where {T,S} = let
  el_same(promote_type(T,S), a, b)
end

#= Definition of eltype =#
Base.eltype(::Type{List{T}}) where {T} = let
  T
end

Base.eltype(::List{T}) where {T} = let
  T
end


Base.eltype(::Type{Nil}) where {T} = let
  Nil
end

Base.eltype(::Nil) where {T} = let
  Any
end

#= For "Efficient" casting... O(N) * C" =#
List(T::Type #= Hack.. =#, args) = let
  local lst::List{T} = nil()
  local t::Array{T} = collect(first(args))
  for i in length(t):-1:1
    lst = Cons{T}(t[i], lst)
  end
  lst
end

#= if the head element is nil the list is empty.=#
nil() = List()
list() = nil()

#= Support for primitive constructs. Numbers. Integer bool e.t.c =#
function list(els::T...)::List{T} where {T <: Number}
  local lst::List{T} = nil()
  for i in length(els):-1:1
    lst = Cons{T}(els[i], lst)
  end
  lst
end

#= Support hieractical constructs. Concrete elements =#
function list(els...)::List
  local S::Type = eltype(els)
  local lst::List{S} = nil()
  for i in length(els):-1:1
    lst = Cons{S}(els[i], lst)
  end
  lst
end

cons(v::T, ::Nil) where {T} = Cons{T}(v, Nil())
cons(v::T, l::Cons{T}) where {T} = Cons{T}(v, l)
cons(v, l::Cons{S}) where {S} = let
  List{S}(v, l)
end
cons(v::Type{A}, l::Type{Cons{B}}) where {S, A <:S, B <:S } = let
  Cons{S}(v, l)
end

# Suggestion for new operator <| also right assoc <| :), See I got a hat
<|(v, lst::Nil)  = cons(v, lst)
<|(v, lst::Cons{T}) where{T} = cons(v, lst)
<|(v::S, lst::Cons{T}) where{T, S <: T} = cons(v, lst)

function Base.length(l::Nil)::Int
  0
end

function Base.length(l::List)::Int
  local n::Int = 0
  for _ in l
    n += 1
  end
  n
end

Base.iterate(::Nil) = nothing
Base.iterate(x::Cons, y::Nil) = nothing
function Base.iterate(l::Cons, state::List = l)
    state.head, state.tail
end

"""
  For list comprehension. Unless we switch to mutable structs this is the way to go I think.
  Seems to be more efficient then what the omc currently does.
"""
list(F, C::Base.Generator) = let
  list(collect(Base.Generator(F, C))...)
end

""" Comprehension without a function(!) """
list(C::Base.Generator) = let
  #= Just apply the element to itself =#
  list(i->i, C)
end

""" Adds the ability for Julia to flatten MMlists """
list(X::Base.Iterators.Flatten) = let
  list([X...]...)
end

"""
  List Reductions
"""
list(X::Base.Generator{Base.Iterators.ProductIterator{Y}, Z}) where {Y,Z} = let
  x = collect(X)
  list(list(i...) for i in view.([x], 1:size(x, 1), :))
end

"""
Generates the transformation:
 @do_threaded_for expr with (iter_names) iterators =>
  \$expr for \$iterator_names in list(zip(\$iters...)...)
"""
function make_threaded_for(expr, iter_names, ranges)
  iterExpr::Expr = Expr(:tuple, iter_names.args...)
  rangeExpr::Expr = ranges = [ranges...][1]
  rangeExprArgs = rangeExpr.args
  :($expr for $iterExpr in [ zip($(rangeExprArgs...))... ]) |> esc
end

macro do_threaded_for(expr::Expr, iter_names::Expr, ranges...)
  make_threaded_for(expr, iter_names, ranges)
end

#= Julia standard sort is pretty good =#
Base.sort(lst::List) = let
  list(sort(collect(lst))...)
end

export List, list, cons, <|, nil
export @do_threaded_for, Cons, Nil

end
