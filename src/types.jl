"""
    AbstractNetworkXGraph{T} <: Graphs.AbstractGraph{T}

Abstract supertype for wrappers around Python NetworkX graph objects.
"""
abstract type AbstractNetworkXGraph{T<:Integer} <: Graphs.AbstractGraph{T} end

"""
    NetworkXGraph{T}(pygraph)
    NetworkXGraph(pygraph)

Wrap an undirected Python `networkx.Graph` as a `Graphs.AbstractGraph`.

Vertices are re-indexed to 1-based Julia integers internally; the original
Python node labels are preserved in `g.nodes` for round-trip fidelity.

# Example
```julia
using NetworkXGraphs
nx = NetworkXGraphs.PythonNetworkX.networkx
pyg = nx.path_graph(5)
gw = NetworkXGraph(pyg)
nv(gw) == 5  # true
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

Vertices are re-indexed to 1-based Julia integers internally; the original
Python node labels are preserved in `g.nodes` for round-trip fidelity.

# Example
```julia
using NetworkXGraphs
nx = NetworkXGraphs.PythonNetworkX.networkx
pyg = nx.DiGraph()
pyg.add_edges_from([(1, 2), (2, 3)])
gw = NetworkXDiGraph(pyg)
is_directed(gw) == true  # true
```
"""
mutable struct NetworkXDiGraph{T<:Integer} <: AbstractNetworkXGraph{T}
    pygraph::Py
    nodes::Vector{Any}
    node_to_index::Dict{Any,T}
end

# ---- Internal helpers -------------------------------------------------------

function _node_to_index(nodes::Vector{Any}, ::Type{T}) where {T<:Integer}
    mapping = Dict{Any,T}()
    for (i, node) in enumerate(nodes)
        mapping[node] = T(i)
    end
    return mapping
end

"""
    refresh_index!(g)

Rebuild the Julia-side vertex index from the current Python node list.
Call this after mutating the underlying `pygraph` directly (outside the
normal API) to keep the wrapper consistent.
"""
function refresh_index!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
    g.nodes = pyconvert(Vector{Any}, pybuiltins.list(g.pygraph.nodes()))
    g.node_to_index = _node_to_index(g.nodes, T)
    return g
end

function _refresh_index_from_nodes!(g::AbstractNetworkXGraph{T}) where {T<:Integer}
    g.node_to_index = _node_to_index(g.nodes, T)
    return g
end

# ---- Constructors -----------------------------------------------------------

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
