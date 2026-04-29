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
