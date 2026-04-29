"""
    networkx_graph(g)

Convert any `Graphs.AbstractGraph` to a raw Python NetworkX graph object.

For `AbstractNetworkXGraph` wrappers this simply returns the underlying
`pygraph` without any copying. For any other `AbstractGraph`, a new
Python `networkx.Graph` or `networkx.DiGraph` is created and populated
with the vertices and edges of `g`.

See also: [`NetworkXGraph`](@ref), [`NetworkXDiGraph`](@ref)
"""
networkx_graph(g::AbstractNetworkXGraph) = g.pygraph

function networkx_graph(g::Graphs.AbstractGraph)
    nx = PythonNetworkX.networkx
    pyg = Graphs.is_directed(g) ? nx.DiGraph() : nx.Graph()
    pyg.add_nodes_from(collect(Graphs.vertices(g)))
    pyg.add_edges_from([(Graphs.src(e), Graphs.dst(e)) for e in Graphs.edges(g)])
    return pyg
end
