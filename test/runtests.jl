using Test
using Base.Threads: nthreads

using Graphs
using GraphsInterfaceChecker
using Interfaces
using NetworkXGraphs
using PythonCall

@testset "NetworkXGraphs.jl" begin
    nx = NetworkXGraphs.PythonNetworkX.networkx

    @testset "Constructors and basic API" begin
        pyg = nx.Graph()
        pyg.add_edges_from([(10, 20), (20, 30), (30, 40)])
        gw = NetworkXGraph(pyg)
        @test gw isa NetworkXGraph
        @test !is_directed(gw)
        @test nv(gw) == 4
        @test ne(gw) == 3
        @test collect(vertices(gw)) == [1, 2, 3, 4]
        @test has_vertex(gw, 1)
        @test !has_vertex(gw, 5)
        @test has_edge(gw, 1, 2)
        @test !has_edge(gw, 1, 4)
        @test sort(outneighbors(gw, 2)) == [1, 3]

        pydg = nx.DiGraph()
        pydg.add_edges_from([(1, 2), (2, 3), (4, 2)])
        dgw = NetworkXDiGraph(pydg)
        @test dgw isa NetworkXDiGraph
        @test is_directed(dgw)
        @test nv(dgw) == 4
        @test ne(dgw) == 3
        @test outneighbors(dgw, 2) == [3]
        @test sort(inneighbors(dgw, 2)) == [1, 4]

        # Graphs.jl -> networkx -> wrapper roundtrip on basic structure.
        g = path_graph(5)
        pyg2 = networkx_graph(g)
        gw2 = NetworkXGraph(pyg2)
        @test nv(gw2) == 5
        @test ne(gw2) == 4
        @test has_edge(gw2, 2, 3)
    end


    @testset "Threaded isolation" begin
        if nthreads() > 1
            results = fill(false, 2 * nthreads())
            PythonCall.GIL.@unlock Threads.@threads for i in eachindex(results)
                pyg = PythonCall.GIL.@lock nx.Graph()
                PythonCall.GIL.@lock pyg.add_edges_from([(1, 2), (2, 3), (3, 4), (4, 5), (5, 5 + i)])
                gw = PythonCall.GIL.@lock NetworkXGraph(pyg)
                ok = gw isa NetworkXGraph
                ok &= PythonCall.GIL.@lock nv(gw) == 6
                ok &= PythonCall.GIL.@lock ne(gw) == 5
                ok &= PythonCall.GIL.@lock has_edge(gw, 1, 2)
                ok &= !PythonCall.GIL.@lock is_directed(gw)

                pydg = PythonCall.GIL.@lock nx.DiGraph()
                PythonCall.GIL.@lock pydg.add_edges_from([(1, 2), (2, 3), (3, 1)])
                dgw = PythonCall.GIL.@lock NetworkXDiGraph(pydg)
                ok &= dgw isa NetworkXDiGraph
                ok &= PythonCall.GIL.@lock is_directed(dgw)
                ok &= PythonCall.GIL.@lock outneighbors(dgw, 2) == [3]
                ok &= PythonCall.GIL.@lock inneighbors(dgw, 2) == [1]
                results[i] = ok
            end
            @test all(results)
        else
            @test true
        end
    end

    @testset "Interface checker" begin
        ug1 = nx.path_graph(5)
        ug2 = nx.complete_graph(4)
        dg1 = nx.DiGraph()
        dg1.add_edges_from([(1, 2), (2, 3), (3, 4)])
        dg2 = nx.complete_graph(4, create_using=nx.DiGraph())
        test_ugraphs = [NetworkXGraph(ug1), NetworkXGraph(ug2)]
        test_dgraphs = [NetworkXDiGraph(dg1), NetworkXDiGraph(dg2)]

        @test Interfaces.test(AbstractGraphInterface, NetworkXGraph, test_ugraphs)
        @test Interfaces.test(AbstractGraphInterface, NetworkXDiGraph, test_dgraphs)
    end

    @testset "Deletion preserves wrapper order" begin
        pyg = nx.path_graph(4)
        gw = NetworkXGraph(pyg)
        @test rem_vertex!(gw, 2)
        @test gw.nodes == Any[0, 3, 2]
        @test gw.node_to_index == Dict{Any,Int}(0 => 1, 3 => 2, 2 => 3)

        gw_copy = copy(gw)
        @test gw_copy.nodes == gw.nodes
        @test gw_copy.node_to_index == gw.node_to_index

        gw_squash, vmap = squash(gw)
        @test gw_squash.nodes == gw.nodes
        @test gw_squash.node_to_index == gw.node_to_index
        @test vmap == [1, 2, 3]

        gw_batch = NetworkXGraph(nx.path_graph(4))
        @test rem_vertex!(gw_batch, 2)
        @test rem_vertices!(gw_batch, [3]) == [1, 2, 0]
        @test gw_batch.nodes == Any[0, 3]
        @test gw_batch.node_to_index == Dict{Any,Int}(0 => 1, 3 => 2)

        dg = NetworkXDiGraph(nx.DiGraph([(1, 2), (2, 3), (3, 4)]))
        @test rem_vertex!(dg, 2)
        @test reverse(dg).nodes == dg.nodes
    end

    @testset "Duplicate edges are rejected" begin
        gw = NetworkXGraph(nx.path_graph(3))
        @test !add_edge!(gw, 1, 2)
        @test ne(gw) == 2
    end
end
