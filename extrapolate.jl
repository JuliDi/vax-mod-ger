using Plots, LsqFit, CSV, DataFrames, Dates, HTTP

# Read CSV File
# table = CSV.File("Impfungen.csv")
table = CSV.File(HTTP.get("https://impfdashboard.de/static/data/germany_vaccinations_timeseries_v2.tsv").body)
df = table |> DataFrame # Save to DataFrame

# Extract dates and number of vaccinations
dates = df[!,"date"]
dates_numeric = Dates.value.(dates - dates[1])
vaccinations = df[!,"personen_erst_kumulativ"]

# Construct including future dates
dates_future = [dates[1] + Day(i) for i in 0:200]
dates_future_numeric = 0:200
# Create exponential model function
# @. model(t, p) = p[1] * exp.(p[2] * t) .+ p[3]
# @. model(t, p) = p[1] * exp(p[2] * t) * t * t
@. model(t, p) = p[1] * t^3 + p[2]

# Think of some random start value, TODO: improve to use more realistic values
p0 = [7.302e+05, 0.02773, 1000]

# Fit the model
fit = curve_fit(model, dates_numeric, vaccinations, p0)

# Get the model parameters
params_model = fit.param

# extrapolate
vax_extrapolated = model(dates_future_numeric, params_model)

# find index where model predicts >80e6 vaccinations
eightymio = findfirst(x -> x > 73e6, model(dates_future_numeric, params_model))

# Use plotly
plotlyjs()

# Make background transparent for export
if isinteractive()
    bg_col = :white
else
    bg_col = :transparent
end

# plot the curve!
p = plot(dates, vaccinations,
            draw_arrow=true,
            legend=:outertopright,
            minorticks=true,
            minorgrid=true,
            ticks=:native,
            seriestype=:scatter,
            markersize=2,
            background_color=bg_col,
            foreground_color=:black,
            linewidth=1,
            label="Actual Vaccinations",
            xlabel="Date (last update: " * string(Dates.format(now(), "Y-m-d, HH:MM") * ")"),
            ylabel="Number of People with min. 1 Dose",
            title="Vaccinations Model Germany",
            # size=(1200,800)
)
plot!(
    dates_future,
    vax_extrapolated,
    linewidth=0.5,
    label="Model (a * x³ + b)",
    ticks=:native)


# Plot horizontal and vertical line for >80 Mio
plot!(
    vcat(dates_future[1:eightymio], dates_future[eightymio]),
    vcat(vax_extrapolated[eightymio] * ones(eightymio), 0),
    label=">73-Mio First-Dose",
    color=:green
    )

if isinteractive()
    display(p)
end

# Save the plot to a file
savefig("Plot_Vax.html")

# Create model params file
res_file = open("results.html","w");
println(res_file, "Model Parameters: <ul>")
println(res_file, "<li>a = ", params_model[1], "</li>")
println(res_file, "<li>b = ", params_model[2], "</li>")
println(res_file, "</ul>")
println(res_file, "<p>>73 Mio First-Dose Vaccinations on ", dates_future[eightymio], "</p>")
close(res_file)
