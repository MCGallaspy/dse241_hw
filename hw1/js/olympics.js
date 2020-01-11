// set the dimensions and margins of the graph
var margin = {top: 10, right: 30, bottom: 30, left: 60},
    width = 460 - margin.left - margin.right,
    height = 400 - margin.top - margin.bottom;

// append the svg object to the body of the page
var svg = d3.select("#viz")
  .append("svg")
  .attr("width", width + margin.left + margin.right)
  .attr("height", height + margin.top + margin.bottom)
  .append("g")
  .attr("transform",
        "translate(" + margin.left + "," + margin.top + ")");

//Read the data
d3.tsv("data/olympics_series.tsv", function(data) {
    series = [];
    for (var year in data)
    {
        if (year === 'index') continue;
        series.push({
                        year: new Date(year),
                        value: +data[year]
                   });
    }
    return {
        country: data['index'],
        series: series,
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
    var y = d3.scaleLinear()
      .domain([0, 1])
      .range([ height, 0 ]); 
    svg.append("g")
      .call(d3.axisLeft(y));
    
    data.forEach(function(d) {
        svg.append("path").datum(d.series)
          .attr("fill", "none")
          .attr("stroke", "steelblue")
          .attr("stroke-width", 1.5)
          .attr("id", d.country)
          .attr("d", d3.line()  
            .x(function(d) { return x(d.year); })
            .y(function(d) { return y(d.value); })
            );
    });
});