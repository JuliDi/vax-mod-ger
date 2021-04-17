using PlotlyJS, LsqFit, CSV, DataFrames, Dates, HTTP

# Download CSV File
println("Downloading new data...")
table = CSV.File(HTTP.get("https://impfdashboard.de/static/data/germany_vaccinations_timeseries_v2.tsv").body)
println("Done!")
df = table |> DataFrame # Save to DataFrame

# Extract dates and number of vaccinations
dates = df[!,"date"]
dates_numeric = Dates.value.(dates - dates[1])
vaccinations = df[!,"personen_erst_kumulativ"]

# Construct including future dates
dates_future_numeric = 0:230
dates_future = [dates[1] + Day(i) for i in dates_future_numeric]

# Create exponential model function
# @. model(t, p) = p[1] * exp.(p[2] * t) .+ p[3]
# @. model(t, p) = p[1] * exp(p[2] * t) * t * t
# @. model(t, p) = p[1] * (t)^3 + p[3]
function model(t, p)
    p[1] .* (t .- p[2]).^3 .+ p[3]
end

# Think of some random start value, TODO: improve to use more realistic values
p0 = [2.0, 2.0, 10000.0]

# Fit the model
fit = curve_fit(model, dates_numeric, vaccinations, p0)

# Get the model parameters
params_model = fit.param

# extrapolate
vax_extrapolated = model(dates_future_numeric, params_model)

# find index where model predicts >80e6 vaccinations
markline_idx = findfirst(x -> x > 73e6, vax_extrapolated)

# Use plotly
# plotlyjs()

# Make background transparent for export
if isinteractive()
    bg_col = :white
else
    bg_col = :transparent
end

# plot the curve!

layout = Layout(
    title="Vaccinations Model Germany<br>(last update: " * string(Dates.format(now(), "Y-m-d, HH:MM") * ")"),
    xaxis=attr(
        title=attr(text="Date"), showgrid=true,
        zeroline=true),
    yaxis=attr(title=attr(text="Number of People with min. 1 Dose", standoff=10), zeroline=false, automargin=true),
);

p_actual = scatter(
    x=dates,
    y=vaccinations,
    mode="markers",
    name="Actual Vaccinations",
    marker=attr(symbol="circle-open")
)

p_model = scatter(
    x=dates_future,
    y=vax_extrapolated,
    linewidth=0.5,
    name="Model (a * x³ + b)",
)

# Plot horizontal and vertical line for >73 Mio
p_lines = scatter(
    x=vcat(dates_future[1:markline_idx], dates_future[markline_idx]),
    y=vcat(vax_extrapolated[markline_idx] * ones(markline_idx), 0),
    name=">73-Mio First-Dose",
    color=:green
)

p = plot([p_actual, p_model, p_lines], layout, options=Dict(:responsive => true, :editable => true))

if isinteractive()
    display(p)
end

# Save the plot to a file
savehtml(p, "Plot_Vax.html", :remote)

# Create model params file
res_file = open("results.html", "w");
println(res_file, "Model Parameters: <ul>")
println(res_file, "<li>a = ", params_model[1], "</li>")
println(res_file, "<li>b = ", params_model[2], "</li>")
println(res_file, "</ul>")
println(res_file, "<p>>73 Mio First-Dose Vaccinations on ", dates_future[markline_idx], "</p>")
close(res_file)
