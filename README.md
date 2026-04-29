# NetworkXGraphs.jl

`NetworkXGraphs.jl` is a Julia wrapper around Python's `networkx` built on `PythonCall.jl`.
The current milestone is intentionally narrow: constructors plus the basic `Graphs.jl` API needed to pass `GraphsInterfaceChecker`.

`networkx` is declared as a package dependency and is automatically installed via `CondaPkg.jl` — no manual Python setup required.

## Features

- Wrap `networkx.Graph`/`networkx.DiGraph` as `Graphs.AbstractGraph` using the `NetworkXGraph` / `NetworkXDiGraph` constructors
- Convert between `Graphs.jl` graph types and Python `networkx` objects via `networkx_graph`
- Access the raw Python `networkx` module through `NetworkXGraphs.PythonNetworkX`
- Validate interface conformance with `GraphsInterfaceChecker.jl`
- Stress-test multi-threaded use of independent graphs to catch Python/GIL integration regressions

## Quick start

```julia
using Graphs
using NetworkXGraphs

# Access the raw Python networkx module
nx = NetworkXGraphs.PythonNetworkX.networkx

# Create a Python networkx graph and wrap it as a Graphs.jl-compatible graph
pyg = nx.path_graph(5)
gw = NetworkXGraph(pyg)         # undirected
nv(gw) == 5                     # true

pydg = nx.DiGraph()
pydg.add_edges_from([(1, 2), (2, 3)])
dgw = NetworkXDiGraph(pydg)     # directed

# Convert a Graphs.jl graph to a Python networkx object
g = path_graph(5)
pyg2 = networkx_graph(g)
gw2 = NetworkXGraph(pyg2)
nv(gw2) == nv(g)                # true
```

## Notes

- No graph algorithms are implemented in this package at this stage.
