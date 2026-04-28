module NetworkX

using Graphs
using PythonCall: Py, pybuiltins, pyconvert, pyimport

export AbstractNetworkXGraph,
	NetworkXGraph,
	NetworkXDiGraph,
	networkx_graph,
	wrap_networkx,
	refresh_index!

"""
	AbstractNetworkXGraph{T} <: Graphs.AbstractGraph{T}

Abstract supertype for wrappers around Python NetworkX graph objects.
"""
abstract type AbstractNetworkXGraph{T<:Integer} <: Graphs.AbstractGraph{T} end

"""
	NetworkXGraph{T}(pygraph)

Wrapper for an undirected NetworkX graph.
"""
mutable struct NetworkXGraph{T<:Integer} <: AbstractNetworkXGraph{T}
	pygraph::Py
	nodes::Vector{Any}
	node_to_index::Dict{Any,T}
end

"""
	NetworkXDiGraph{T}(pygraph)

Wrapper for a directed NetworkX graph.
"""
mutable struct NetworkXDiGraph{T<:Integer} <: AbstractNetworkXGraph{T}
	pygraph::Py
	nodes::Vector{Any}
	node_to_index::Dict{Any,T}
end

const _NX = Ref{Py}()

_nx() = isassigned(_NX) ? _NX[] : (_NX[] = pyimport("networkx"))
_pylist(x) = pybuiltins.list(x)
_nodes(pygraph::Py) = pyconvert(Vector{Any}, _pylist(pygraph.nodes()))
_edges(pygraph::Py) = pyconvert(Vector{Tuple{Any,Any}}, _pylist(pygraph.edges()))
_neighbors(pyiter) = pyconvert(Vector{Any}, _pylist(pyiter))

function _node_to_index(nodes::Vector{Any}, ::Type{T}) where {T<:Integer}
	mapping = Dict{Any,T}()
	for (i, node) in enumerate(nodes)
		mapping[node] = T(i)
	end
	return mapping
end

function refresh_index!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
	nodes = _nodes(g.pygraph)
	g.nodes = nodes
	g.node_to_index = _node_to_index(nodes, T)
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
	wrap_networkx(pygraph; T=Int)

Wrap a NetworkX Python graph object as a `Graphs.AbstractGraph` implementation.
"""
function wrap_networkx(pygraph::Py; T::Type{<:Integer}=Int)
	return pyconvert(Bool, pygraph.is_directed()) ? NetworkXDiGraph{T}(pygraph) :
		   NetworkXGraph{T}(pygraph)
end

"""
	networkx_graph(g)

Convert a `Graphs.AbstractGraph` to a Python NetworkX graph object.
"""
networkx_graph(g::AbstractNetworkXGraph) = g.pygraph

function networkx_graph(g::Graphs.AbstractGraph)
	nx = _nx()
	pyg = Graphs.is_directed(g) ? nx.DiGraph() : nx.Graph()
	pyg.add_nodes_from(collect(Graphs.vertices(g)))
	pyg.add_edges_from([(Graphs.src(e), Graphs.dst(e)) for e in Graphs.edges(g)])
	return pyg
end

wrap_networkx(g::Graphs.AbstractGraph{T}) where {T<:Integer} =
	wrap_networkx(networkx_graph(g); T=T)

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
_label_to_vertex(g::AbstractNetworkXGraph{T}, label) where {T<:Integer} =
	g.node_to_index[label]::T
_label_to_vertex(g::Graphs.AbstractGraph, label) = label

function Graphs.has_edge(g::AbstractNetworkXGraph, s, d)
	Graphs.has_vertex(g, s) || return false
	Graphs.has_vertex(g, d) || return false
	return pyconvert(Bool, g.pygraph.has_edge(_node(g, s), _node(g, d)))
end

function _mapped_neighbors(g::AbstractNetworkXGraph{T}, pyiter) where {T<:Integer}
	py_ns = _neighbors(pyiter)
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
	return Graphs.Edge{T}[
		Graphs.Edge{T}(g.node_to_index[u], g.node_to_index[v]) for (u, v) in _edges(g.pygraph)
	]
end

Graphs.has_self_loops(g::AbstractNetworkXGraph) = pyconvert(Int, _nx().number_of_selfloops(g.pygraph)) > 0

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
	copyg = wrap_networkx(g.pygraph.copy(); T=Int)
	copyg.nodes = copy(g.nodes)
	_refresh_index_from_nodes!(copyg)
	return copyg, collect(Graphs.vertices(g))
end

Graphs.zero(::Type{<:NetworkXGraph{T}}) where {T<:Integer} = wrap_networkx(_nx().Graph(); T=T)
Graphs.zero(::Type{<:NetworkXDiGraph{T}}) where {T<:Integer} =
	wrap_networkx(_nx().DiGraph(); T=T)

function Base.copy(g::NetworkXGraph{T}) where {T<:Integer}
	copyg = NetworkXGraph{T}(g.pygraph.copy())
	copyg.nodes = copy(g.nodes)
	copyg.node_to_index = copy(g.node_to_index)
	return copyg
end

function Base.copy(g::NetworkXDiGraph{T}) where {T<:Integer}
	copyg = NetworkXDiGraph{T}(g.pygraph.copy())
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

end # module NetworkX
