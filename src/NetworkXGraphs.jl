module NetworkXGraphs

using Graphs
using PythonCall: Py, pynew, pycopy!, pybuiltins, pyconvert, pyimport

export AbstractNetworkXGraph,
	NetworkXGraph,
	NetworkXDiGraph,
	networkx_graph,
	refresh_index!

"""
	NetworkXGraphs.PythonNetworkX

Sub-module providing direct access to the Python `networkx` package.
Use this namespace when you need raw Python networkx objects or algorithms
that are not yet wrapped by the Julia API.

# Example
```julia
using NetworkXGraphs
nx = NetworkXGraphs.PythonNetworkX.networkx
pyg = nx.complete_graph(5)
```
"""
module PythonNetworkX
using PythonCall: pynew, pycopy!, pyimport

"""The raw Python `networkx` module."""
const networkx = pynew()

function __init__()
    pycopy!(networkx, pyimport("networkx"))
end
end # module PythonNetworkX

"""
	AbstractNetworkXGraph{T} <: Graphs.AbstractGraph{T}

Abstract supertype for wrappers around Python NetworkX graph objects.
"""
abstract type AbstractNetworkXGraph{T<:Integer} <: Graphs.AbstractGraph{T} end

"""
	NetworkXGraph{T}(pygraph)
	NetworkXGraph(pygraph)

Wrap an undirected Python `networkx.Graph` as a `Graphs.AbstractGraph`.

# Example
```julia
using NetworkXGraphs
nx = NetworkXGraphs.PythonNetworkX.networkx
pyg = nx.path_graph(5)
gw = NetworkXGraph(pyg)
```
"""
mutable struct NetworkXGraph{T<:Integer} <: AbstractNetworkXGraph{T}
	pygraph::Py
	nodes::Vector{Any}
	node_to_index::Dict{Any,T}
end

"""
	NetworkXDiGraph{T}(pygraph)
	NetworkXDiGraph(pygraph)

Wrap a directed Python `networkx.DiGraph` as a `Graphs.AbstractGraph`.

# Example
```julia
using NetworkXGraphs
nx = NetworkXGraphs.PythonNetworkX.networkx
pyg = nx.DiGraph()
pyg.add_edges_from([(1, 2), (2, 3)])
gw = NetworkXDiGraph(pyg)
```
"""
mutable struct NetworkXDiGraph{T<:Integer} <: AbstractNetworkXGraph{T}
	pygraph::Py
	nodes::Vector{Any}
	node_to_index::Dict{Any,T}
end

function _node_to_index(nodes::Vector{Any}, ::Type{T}) where {T<:Integer}
	mapping = Dict{Any,T}()
	for (i, node) in enumerate(nodes)
		mapping[node] = T(i)
	end
	return mapping
end

function refresh_index!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	g.nodes = pyconvert(Vector{Any}, pybuiltins.list(g.pygraph.nodes()))
	g.node_to_index = _node_to_index(g.nodes, T)
	return g
end

function _refresh_index_from_nodes!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	g.node_to_index = _node_to_index(g.nodes, T)
	return g
end

function NetworkXGraph{T}(pygraph::Py) where {T<:Integer}
	pyconvert(Bool, pygraph.is_directed()) &&
		throw(ArgumentError("Expected an undirected networkx.Graph."))
	g = NetworkXGraph{T}(pygraph, Any[], Dict{Any,T}())
	return refresh_index!(g)
end

NetworkXGraph(pygraph::Py) = NetworkXGraph{Int}(pygraph)

function NetworkXDiGraph{T}(pygraph::Py) where {T<:Integer}
	!pyconvert(Bool, pygraph.is_directed()) &&
		throw(ArgumentError("Expected a directed networkx.DiGraph."))
	g = NetworkXDiGraph{T}(pygraph, Any[], Dict{Any,T}())
	return refresh_index!(g)
end

NetworkXDiGraph(pygraph::Py) = NetworkXDiGraph{Int}(pygraph)

"""
	networkx_graph(g)

Convert a `Graphs.AbstractGraph` to a Python NetworkX graph object.
Returns the underlying Python object for `AbstractNetworkXGraph` wrappers,
or creates a new Python networkx graph for any other `Graphs.AbstractGraph`.
"""
networkx_graph(g::AbstractNetworkXGraph) = g.pygraph

function networkx_graph(g::Graphs.AbstractGraph)
	nx = PythonNetworkX.networkx
	pyg = Graphs.is_directed(g) ? nx.DiGraph() : nx.Graph()
	pyg.add_nodes_from(collect(Graphs.vertices(g)))
	pyg.add_edges_from([(Graphs.src(e), Graphs.dst(e)) for e in Graphs.edges(g)])
	return pyg
end

Graphs.is_directed(::Type{<:NetworkXGraph}) = false
Graphs.is_directed(::NetworkXGraph) = false
Graphs.is_directed(::Type{<:NetworkXDiGraph}) = true
Graphs.is_directed(::NetworkXDiGraph) = true

Graphs.edgetype(::AbstractNetworkXGraph{T}) where {T<:Integer} = Graphs.Edge{T}
Graphs.nv(g::AbstractNetworkXGraph) = length(g.nodes)
Graphs.ne(g::AbstractNetworkXGraph) = pyconvert(Int, g.pygraph.number_of_edges())
Graphs.vertices(g::AbstractNetworkXGraph{T}) where {T<:Integer} = T.(1:Graphs.nv(g))
Graphs.has_vertex(g::AbstractNetworkXGraph, v) = 1 <= v <= Graphs.nv(g)
Graphs.eltype(::Type{G}) where {T<:Integer,G<:AbstractNetworkXGraph{T}} = T
Graphs.eltype(::AbstractNetworkXGraph{T}) where {T<:Integer} = T

_node(g::AbstractNetworkXGraph, v::Integer) = g.nodes[Int(v)]

function Graphs.has_edge(g::AbstractNetworkXGraph, s, d)
	Graphs.has_vertex(g, s) || return false
	Graphs.has_vertex(g, d) || return false
	return pyconvert(Bool, g.pygraph.has_edge(_node(g, s), _node(g, d)))
end

function _mapped_neighbors(g::AbstractNetworkXGraph{T}, pyiter) where {T<:Integer}
	py_ns = pyconvert(Vector{Any}, pybuiltins.list(pyiter))
	return T[g.node_to_index[n] for n in py_ns]
end

function Graphs.outneighbors(g::NetworkXGraph{T}, v) where {T<:Integer}
	Graphs.has_vertex(g, v) || return T[]
	return _mapped_neighbors(g, g.pygraph.neighbors(_node(g, v)))
end

Graphs.inneighbors(g::NetworkXGraph{T}, v) where {T<:Integer} = Graphs.outneighbors(g, v)

function Graphs.outneighbors(g::NetworkXDiGraph{T}, v) where {T<:Integer}
	Graphs.has_vertex(g, v) || return T[]
	return _mapped_neighbors(g, g.pygraph.successors(_node(g, v)))
end

function Graphs.inneighbors(g::NetworkXDiGraph{T}, v) where {T<:Integer}
	Graphs.has_vertex(g, v) || return T[]
	return _mapped_neighbors(g, g.pygraph.predecessors(_node(g, v)))
end

function Graphs.edges(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	py_edges = pyconvert(Vector{Tuple{Any,Any}}, pybuiltins.list(g.pygraph.edges()))
	return Graphs.Edge{T}[
		Graphs.Edge{T}(g.node_to_index[u], g.node_to_index[v]) for (u, v) in py_edges
	]
end

Graphs.has_self_loops(g::AbstractNetworkXGraph) =
	pyconvert(Int, PythonNetworkX.networkx.number_of_selfloops(g.pygraph)) > 0

function Graphs.add_vertex!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	new_index = T(Graphs.nv(g) + 1)
	label = new_index
	# Find a unique label if it already exists in the Python graph
	while pyconvert(Bool, g.pygraph.has_node(label))
		new_index += one(T)
		label = new_index
	end
	g.pygraph.add_node(label)
	push!(g.nodes, label)
	g.node_to_index[label] = T(length(g.nodes))
	return true
end

function Graphs.add_edge!(g::AbstractNetworkXGraph, s, d)
	Graphs.has_vertex(g, s) || return false
	Graphs.has_vertex(g, d) || return false
	Graphs.has_edge(g, s, d) && return false
	g.pygraph.add_edge(_node(g, s), _node(g, d))
	return true
end

function Graphs.rem_edge!(g::AbstractNetworkXGraph, s, d)
	if Graphs.has_edge(g, s, d)
		g.pygraph.remove_edge(_node(g, s), _node(g, d))
		return true
	end
	return false
end

function Graphs.rem_vertex!(g::AbstractNetworkXGraph{T}, v) where {T<:Integer}
	Graphs.has_vertex(g, v) || return false
	label = _node(g, v)
	g.pygraph.remove_node(label)
	# O(1) removal: swap with last node and pop
	if v != length(g.nodes)
		last_label = g.nodes[end]
		g.nodes[v] = last_label
		g.node_to_index[last_label] = T(v)
	end
	pop!(g.nodes)
	delete!(g.node_to_index, label)
	return true
end

function Graphs.rem_vertices!(g::AbstractNetworkXGraph{T}, vs; keep_order::Bool=true) where {T<:Integer}
	remove_set = Set{T}(T.(collect(vs)))
	old_vertices = collect(Graphs.vertices(g))
	for v in old_vertices
		if v in remove_set
			g.pygraph.remove_node(_node(g, v))
		end
	end
	g.nodes = [g.nodes[v] for v in old_vertices if !(v in remove_set)]
	_refresh_index_from_nodes!(g)
	vmap = zeros(T, length(old_vertices))
	new_index = one(T)
	for v in old_vertices
		if !(v in remove_set)
			vmap[v] = new_index
			new_index += one(T)
		end
	end
	return vmap
end

function Graphs.squash(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	copyg = typeof(g)(g.pygraph.copy())
	copyg.nodes = copy(g.nodes)
	_refresh_index_from_nodes!(copyg)
	return copyg, collect(Graphs.vertices(g))
end

Graphs.zero(::Type{<:NetworkXGraph{T}}) where {T<:Integer} =
	NetworkXGraph{T}(PythonNetworkX.networkx.Graph())
Graphs.zero(::Type{<:NetworkXDiGraph{T}}) where {T<:Integer} =
	NetworkXDiGraph{T}(PythonNetworkX.networkx.DiGraph())

function Base.copy(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	copyg = typeof(g)(g.pygraph.copy())
	copyg.nodes = copy(g.nodes)
	copyg.node_to_index = copy(g.node_to_index)
	return copyg
end

function Base.reverse(g::NetworkXDiGraph{T}) where {T<:Integer}
	reversed = NetworkXDiGraph{T}(g.pygraph.reverse(copy=true))
	reversed.nodes = copy(g.nodes)
	reversed.node_to_index = copy(g.node_to_index)
	return reversed
end

end # module NetworkXGraphs
