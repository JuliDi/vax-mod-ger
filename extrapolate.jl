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
dates_future_numeric = 0:300
dates_future = [dates[1] + Day(i) for i in dates_future_numeric]

# Create exponential model function
# @. model(t, p) = p[1] * exp.(p[2] * t) .+ p[3]
# @. model(t, p) = p[1] * exp(p[2] * t) * t * t
# @. model(t, p) = p[1] * (t)^3 + p[3]
function model(t, p)
    p[1] .* t .+ p[2] .* t.^2 .+ p[3] .* t.^3 .+ p[4];
end

# Think of some random start value, TODO: improve to use more realistic values
# p0 = [2.0, 2.0, 10000.0]
p0 = [5e3, 2.0, 2.0, 10000.0]
ub = [8e6, 8e6, 8e6, 1e10]

# Fit the model
fit = curve_fit(model, dates_numeric, vaccinations, p0, upper=ub)

# Get the model parameters
params_model = fit.param

# extrapolate
vax_extrapolated = model(dates_future_numeric, params_model)

# estimate vaccinations per day (1st derivative)
vax_per_day =
    params_model[1] .+ 2 .*  params_model[2] .* dates_future_numeric .+ 3 .* params_model[3] .* dates_future_numeric.^2;

# find index where model predicts >80e6 vaccinations
markline_idx = findfirst(x -> x > 73e6, vax_extrapolated)

# Use plotly
# plotlyjs()

# Make background transparent for export
if isinteractive()
    bg_col = "#FFF"
else
    bg_col = "rgba(0,0,0,0)"
end

# plot the curve!

layout = Layout(
    title=attr(
        text="Vaccinations Model Germany<br>(last update: " * string(Dates.format(now(), "Y-m-d, HH:MM") * ")"),
    ),
    xaxis=attr(
        title=attr(text="Date"),
        showgrid=true,
        zeroline=true,
        rangeslider=attr(
            # visible=true,
            visible=false,
            yaxis=attr(rangemode="auto"),
        ),
        range=[dates_future[1] - Day(10), dates_future[markline_idx] + Day(10)],
    ),
    yaxis=attr(
        title=attr(
            text="Number of People with min. 1 Dose",
            standoff=10),
        zeroline=false,
        automargin=true,
        rangemode="tozero",
        scaleanchor="y2",
        scaleratio=1 / 10,
        range=[0, maximum(vax_extrapolated[markline_idx] * 1.1)]
    ),
    yaxis2=attr(
        title=attr(
            text="Vaccinations per Day",
            standoff=10),
        overlaying="y",
        side="right",
        scaleanchor="y",
        scaleratio=10,
        constraintoward="bottom",
        rangemode="tozero",

    ),
    paper_bgcolor=bg_col,
    plot_bgcolor=bg_col,
    legend=attr(
        orientation="h",
        x="0.5",
        xanchor="center",
    ),
    hovermode="x unified",
    hoverlabel=attr(namelength=-1) 
);

p_actual = scatter(
    x=dates,
    y=vaccinations,
    mode="markers",
    name="Actual Vaccinations (Cumulative)",
    marker=attr(symbol="circle-open"),
    marker_color="blue"
)

p_model = scatter(
    x=dates_future,
    y=vax_extrapolated,
    linewidth=0.5,
    name="Model (a*x + b*x² + c*x³ + d)",
    marker_color="dodgerblue"
)

p_vpd = scatter(
    x=dates,
    y=df.dosen_erst_differenz_zum_vortag,
    mode="markers",
    name="Actual Vaccinations per Day",
    marker=attr(symbol="diamond-open"),
    yaxis="y2",
    marker_color="red"
)

p_model_vpd = scatter(
    x=dates_future,
    y=vax_per_day,
    linewidth=0.5,
    name="Vaccinations per Day (Model)",
    yaxis="y2",
    marker_color="crimson"
)

# Plot horizontal and vertical line for >73 Mio
p_lines = scatter(
    x=vcat(dates_future[1:markline_idx], dates_future[markline_idx]),
    y=vcat(vax_extrapolated[markline_idx] * ones(markline_idx), 0),
    name=">73-Mio First-Dose",
    marker_color="green"
)

p = plot(
    [p_actual, p_model, p_vpd, p_model_vpd, p_lines],
    layout,
    options=Dict(:responsive => true),
    )

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
println(res_file, "<li>c = ", params_model[3], "</li>")
println(res_file, "<li>d = ", params_model[4], "</li>")
println(res_file, "</ul>")
println(res_file, "<p>>73 Mio First-Dose Vaccinations on ", dates_future[markline_idx], "</p>")
close(res_file)
