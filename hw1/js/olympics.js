// set the dimensions and margins of the graph
var mult = 1.4;
var margin = {top: 30, right: 30, bottom: 30, left: 60},
    width = mult*460 - margin.left - margin.right,
    height = mult*400 - margin.top - margin.bottom;

// append the svg object to the body of the page
var svg = d3.select("#viz")
  .append("svg")
  .attr("width", width + margin.left + margin.right)
  .attr("height", height + margin.top + margin.bottom)
  .append("g")
  .attr("transform",
        "translate(" + margin.left + "," + margin.top + ")");

//Read the data

var n = -1;

d3.tsv("data/olympics_series.tsv", function(data) {
    series = [];
    for (var year in data)
    {
        if (year === 'index') continue;
        series.push({
                        year: new Date(year),
                        value: +data[year],
                   });
    }
    n += 1;
    return {
        country: data['index'],
        series: series,
        color_index: n,
        };
    }).then(function(data) {
    
    // Add X axis --> it is a date format
    var x = d3.scaleTime()
      .domain(d3.extent(data[0].series, function(d) { return d.year; }))
      .range([ 0, width ]);
    svg.append("g")
      .attr("transform", "translate(0," + height + ")")
      .call(d3.axisBottom(x));
    
    // Add Y axis
    ymin = d3.min(data, function(d) { return d3.min(d.series, function(s) { return s.value }); });
    ymax = d3.max(data, function(d) { return d3.max(d.series, function(s) { return s.value }); });
    var y = d3.scaleLinear()
      .domain([ ymin, ymax ])
      .range([ height, 0 ]);
    svg.append("g")
      .call(d3.axisLeft(y));
    
    data.forEach(function(d) {
        var country = d.country;
        var path = svg.append("path").datum(d.series)
          .attr("fill", "none")
          .attr("stroke", d3.schemeCategory10[d.color_index])
          .attr("stroke-width", 1.5)
          .attr("id", country)
          .attr("class", "seriesLine")
          .attr("d", d3.line()  
            .x(function(d) { return x(d.year); })
            .y(function(d) { return y(d.value); })
            )
          .style('mix-blend-mode', "multiply");
    });
    
    svg.style("position", "relative");
  
    d3.select("#viz svg").on("mouseenter", entered)
       .on("mousemove", moved)
       .on("mouseleave", left);

    const dot = svg.append("g")
      .attr("display", "none");

    dot.append("circle")
      .attr("r", 2.5);

    dot.append("text")
      .style("font", "10px sans-serif")
      .attr("text-anchor", "middle")
      .attr("y", -8);

    var date_extent = [];
    data[0].series.forEach(function (e) {date_extent.push(e.year)});
    function moved() {
        // When the mouse moves, find the closest point on one of the lines
        // Illustrate a dot there and highlight the line.
        d3.event.preventDefault();
        const ym = y.invert(d3.event.layerY - margin.top);
        const xm = x.invert(d3.event.layerX - margin.left);
        const i1 = d3.bisectLeft(date_extent, xm);
        const i0 = Math.max(i1 - 1, 0);
        console.log(i1, i0);
        const i = Math.abs(xm - date_extent[i0]) > Math.abs(xm - date_extent[i1]) ? i1: i0;
        const s = data.reduce(function(a, b){
            return Math.abs(a.series[i].value - ym) < Math.abs(b.series[i].value - ym) ? a : b
        });
        dot.attr("transform", `translate(${x(data[0].series[i].year)},${y(s.series[i].value)})`);
        dot.select("text").text(s.country).style('background', 'white');
        d3.selectAll(".seriesLine").attr("r", 10).style("stroke", "gray").style('mix-blend-mode', null)
            .attr("stroke-width", 1.5);
        d3.select("#" + s.country).attr("r", 10).style("stroke", d3.schemeCategory10[s.color_index]).attr("stroke-width", 2.0)
          .style('mix-blend-mode', "multiply");
    }

    function entered() {
        d3.selectAll(".seriesLine").style('mix-blend-mode', null);
        dot.attr("display", null);
    }

    function left() {
        data.forEach(function(d) {
            d3.select("#" + d.country).style("stroke", d3.schemeCategory10[d.color_index])
                .style('mix-blend-mode', "multiply").attr("stroke-width", 1.5);
        });
        //d3.selectAll(".seriesLine").attr("r", 10).style("stroke", "steelblue")
        dot.attr("display", "none");
    }
});