# ---- Directedness -----------------------------------------------------------

Graphs.is_directed(::Type{<:NetworkXGraph})   = false
Graphs.is_directed(::NetworkXGraph)           = false
Graphs.is_directed(::Type{<:NetworkXDiGraph}) = true
Graphs.is_directed(::NetworkXDiGraph)         = true

# ---- Basic properties -------------------------------------------------------

Graphs.edgetype(::AbstractNetworkXGraph{T}) where {T<:Integer} = Graphs.Edge{T}
Graphs.nv(g::AbstractNetworkXGraph)                            = length(g.nodes)
Graphs.ne(g::AbstractNetworkXGraph)                            = pyconvert(Int, g.pygraph.number_of_edges())
Graphs.vertices(g::AbstractNetworkXGraph{T}) where {T<:Integer} = T.(1:Graphs.nv(g))
Graphs.has_vertex(g::AbstractNetworkXGraph, v)                 = 1 <= v <= Graphs.nv(g)
Graphs.eltype(::Type{G}) where {T<:Integer,G<:AbstractNetworkXGraph{T}} = T
Graphs.eltype(::AbstractNetworkXGraph{T}) where {T<:Integer}   = T

# ---- Internal: map Julia vertex index -> Python node label ------------------

_node(g::AbstractNetworkXGraph, v::Integer) = g.nodes[Int(v)]

# ---- Edge queries -----------------------------------------------------------

function Graphs.has_edge(g::AbstractNetworkXGraph, s, d)
    Graphs.has_vertex(g, s) || return false
    Graphs.has_vertex(g, d) || return false
    return pyconvert(Bool, g.pygraph.has_edge(_node(g, s), _node(g, d)))
end

# ---- Neighbors --------------------------------------------------------------

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

# ---- Edge iteration ---------------------------------------------------------

function Graphs.edges(g::AbstractNetworkXGraph{T}) where {T<:Integer}
    py_edges = pyconvert(Vector{Tuple{Any,Any}}, pybuiltins.list(g.pygraph.edges()))
    return Graphs.Edge{T}[
        Graphs.Edge{T}(g.node_to_index[u], g.node_to_index[v]) for (u, v) in py_edges
    ]
end

# ---- Self-loops -------------------------------------------------------------

Graphs.has_self_loops(g::AbstractNetworkXGraph) =
    pyconvert(Int, PythonNetworkX.networkx.number_of_selfloops(g.pygraph)) > 0

# ---- Mutation ---------------------------------------------------------------

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

function Graphs.rem_vertices!(
    g::AbstractNetworkXGraph{T}, vs; keep_order::Bool=true
) where {T<:Integer}
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

# ---- Copy / zero / reverse / squash -----------------------------------------

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
