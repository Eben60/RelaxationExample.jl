module RelaxationExample

using Plots, XLSX, DataFrames, Unitful
using GivEmExel

using NonlinearSolve

using Unitful: ϵ0

export timerange, nl_lsq_fit, expmodel,  proc_data, saveplots, getplots #, anyfy_col!, prepare_xl, sep_unit # , proc_dataset
export _proc_dataspan


DATATABLENAME = "data"


function timerange(df0, t1, t2)
    df = subset(df0, :ts => x -> (x.>t1).&(x.<t2))
    ts = Float64.(df[!, :ts]);
    ys = Float64.(df[!, :ys]);
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

function _proc_dataspan(df, t_start, t_stop)
    t_start = t_start |> ustrip
    t_stop = t_stop |> ustrip
    (; ts, ys) = timerange(df, t_start, t_stop);
    aᵢ = (ys[1])
    τᵢ = (t_stop - t_start) / 2
    t₀ᵢ = t_start
    (;sol, fit) = nl_lsq_fit(expmodel, [aᵢ, τᵢ], ts, ys, t₀ᵢ)
    a, τ = sol.u
    pl = plot(ts, [ys, fit]; label = ["experiment" "fit"])
    return (;a, τ, sol, fit, pl)
end


function _readdata(fl)
    df = DataFrame(XLSX.readtable(fl, DATATABLENAME; infer_eltypes=true))
    ts = df[!, :ts];
    ys = df[!, :ys];
    pl0 = plot(ts, ys)
    return (; df, pl0)
end

_calc_thickness(C, ϵ, area) = ϵ * ϵ0 * area / C |> u"µm"

function _finalize_plot!(pl, params)
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

function proc_data(xlfile, datafile, paramsets; throwonerr=false)
    results = []
    results_df = []
    errors = []
    overview = (;)
    try
        (; df, pl0) = _readdata(xlfile)
        overview = (;pl0, subset=0)
        for (i, pm) in pairs(paramsets)
                (; area, Vunit, timeunit, Cunit, R, ϵ, no, plot_annotation, comment, t_start, t_stop) = pm
            try
                rslt = _proc_dataspan(df, t_start, t_stop)
                (;a, τ, sol, pl) = rslt
                _finalize_plot!(pl, pm)
                rs = (;subset=i, no, a, τ, sol, pl, plot_annotation)
                a *= Vunit
                τ *= timeunit
                c = (τ / R) 
                c = c |> Cunit 
                d = _calc_thickness(c, ϵ, area)
                rs_row = (;no, a, τ, c, d, R, ϵ, comment, t_start, t_stop)
                push!(results, rs)
                push!(results_df, rs_row)
            catch exceptn
                back_trace = catch_backtrace()
                push!(errors, (;row=i, comment, exceptn, back_trace))
                throwonerr && rethrow(exceptn)
            end
        end
        results_df=DataFrame(results_df)
    catch exceptn
        back_trace = catch_backtrace()
        push!(errors,(;row=-1, comment="error opening of processing data file", exceptn, back_trace))
        throwonerr && rethrow(exceptn)
    end
    return (; results, errors, results_df, overview)
end

end # module RelaxationExample
