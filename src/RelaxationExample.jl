module RelaxationExample

using GivEmExel
using Plots, XLSX, DataFrames, NonlinearSolve

export timerange, nl_lsq_fit, expmodel, proc_dataspan, proc_data # , proc_dataset

DATATABLENAME = "data"


function timerange(df0, t1, t2)
    df = subset(df0, :ts => x -> (x.>t1).&(x.<t2))
    ts = df[!, :ts];
    ys = df[!, :ys];
    return (; ts, ys)
end

function nl_lsq_fit(model, u0, xdata, ydata, p)
    data = (xdata, ydata, p)

    function lossfn!(du, u, data)
        (xs, ys, p) = data   
        du .= model.(xs, Ref(u), Ref(p)) .- ys
        return nothing
    end

    prob = NonlinearLeastSquaresProblem(
        NonlinearFunction(lossfn!, resid_prototype = similar(ydata)), u0, data)
    sol = solve(prob)
    u = sol.u
    fit = model.(xdata, Ref(u), Ref(p))
    return (;sol, fit)
end

function expmodel(x, u, t₀=0)
    # y0 = u[1]
    a = u[1]
    τ = u[2]
    return a * exp(-(x-t₀)/τ) # + y0 
end

function proc_dataspan(df, t_start, t_stop)
    (; ts, ys) = timerange(df, t_start, t_stop);
    aᵢ = (ys[1])
    τᵢ = (t_stop - t_start) / 2
    t₀ᵢ = t_start
    (;sol, fit) = nl_lsq_fit(expmodel, [aᵢ, τᵢ], ts, ys, t₀ᵢ)
    a, τ = sol.u
    pl1 = plot(ts, [ys, fit]; label = ["experiment" "fit"])
    return (;a, τ, sol, fit, pl1)
end


function readdata(fl)
    df = DataFrame(XLSX.readtable(fl, DATATABLENAME; infer_eltypes=true))
    ts = df[!, :ts];
    ys = df[!, :ys];
    pl0 = plot(ts, ys)
    return (; df, pl0)
end

# function proc_dataset(fl)
#     (; df, pl0) = readdata(fl)
#     t_start, t_stop = 6.0, 12.0
#     (;a, τ, sol, fit, pl1) = proc_dataspan(df, t_start, t_stop)
#     return (;a, τ, sol, fit, pl0, pl1) 
# end

function finalize_plot!(pl, params)
    (; Vunit, timeunit, plot_annotation) = params
    sz = (800, 600)
    xunit = timeunit |> string
    yunit = Vunit |> string
    pl = plot!(pl; 
        size=sz, 
        xlabel = "time [$xunit]", 
        ylabel = "Voltage [$yunit]", 
        title = "$plot_annotation",
        )
    return pl
end



function proc_data(xlfile, unusedfile, paramsets)
    (; df, pl0) = readdata(xlfile)
    results = []
    for pm in paramsets
        (; area, Vunit, timeunit, R, ϵ, no, plot_annotation, comment, t_start, t_stop) = pm
        rslt = proc_dataspan(df, t_start, t_stop)
        (;a, τ, sol, pl1) = rslt
        finalize_plot!(pl1, pm)
        rs = (;a, τ, sol, pl1) 
        push!(results, rs)
    end
    return results
end

end # module RelaxationExample
