module NetworkXGraphs

using Graphs
using PythonCall: Py, pynew, pycopy!, pybuiltins, pyconvert, pyimport

export AbstractNetworkXGraph,
    NetworkXGraph,
    NetworkXDiGraph,
    networkx_graph,
    refresh_index!

include("python_networkx.jl")
include("types.jl")
include("graph_api.jl")
include("conversions.jl")

end # module NetworkXGraphs

