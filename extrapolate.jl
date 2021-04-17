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
@. model(t, p) = p[1] * exp.(p[2] * t) .+ p[3]

# Think of some random start value, TODO: improve to use more realistic values
p0 = [7.302e+05, 0.02773, 1000]

# Fit the model
fit = curve_fit(model, dates_numeric, vaccinations, p0)

# Get the model parameters
params_model = fit.param

# extrapolate
vax_extrapolated = model(dates_future_numeric, params_model)

# find index where model predicts >80e6 vaccinations
eightymio = findfirst(x -> x > 80e6, model(dates_future_numeric, params_model))

# Use plotly
plotlyjs()

# plot the curve!
p = plot(dates, vaccinations,
            draw_arrow=true,
            legend=:outertopright,
            minorticks=true,
            minorgrid=true,
            ticks=:native,
            seriestype=:scatter,
            markersize=2,
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
    label="Model",
    ticks=:native)


# Plot horizontal and vertical line for >80 Mio
plot!(
    vcat(dates_future[1:eightymio], dates_future[eightymio]),
    vcat(vax_extrapolated[eightymio] .* ones(eightymio), 0),
    label=">80-Mio First-Dose",
    color=:green
    )

savefig("Plot_Vax.html")

