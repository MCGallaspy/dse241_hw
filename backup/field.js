var linecolour = "#ffffff"   
var fillcolour = "#A1C349"

var holder = d3.select("body") // select the 'body' element
      .append("svg")           // append an SVG element to the body
      .attr("id", "field")
	  .attr("width", 1300)      
      .attr("height", 633);

function range(start, end, step = 1) {
  const allNumbers = [start, end, step].every(Number.isFinite);
    if (!allNumbers) {
        throw new TypeError('range() expects only finite numbers as arguments.');
    }
    if (step <= 0) {
        throw new Error('step must be a number greater than 0.');
    }
    if (start > end) {
        step = -step;
    }
  const length = Math.floor(Math.abs((end - start) / step)) + 1;
return Array.from(Array(length), (x, index) => start + index * step);
};

var incFieldArray = range(10,100,5);
			  

    
// Total Grass    
holder.append("rect")        // attach a rectangle
    .attr("x", 0)         // position the left of the rectangle
    .attr("y", 0)          // position the top of the rectangle
    .attr("height", 633)    // set the height
    .attr("width", 1300)    // set the width
    .style("fill", fillcolour);   // set the fill colour    

// draw a rectangle pitch outline    
holder.append("rect")        // attach a rectangle
    .attr("x", 50)         // position the left of the rectangle
    .attr("y", 50)          // position the top of the rectangle
    .attr("height", 533)    // set the height
    .attr("width", 1200)    // set the width
    .style("stroke-width", 5)    // set the stroke width
    .style("stroke", linecolour)   // set the line colour
    .style("fill", fillcolour);    // set the fill colour     

// draw a rectangle - end zone 1
holder.append("rect")        // attach a rectangle
    .attr("x", 50)         // position the left of the rectangle
    .attr("y", 50)          // position the top of the rectangle
    .attr("height", 533)    // set the height
    .attr("width", 100)    // set the width
    .style("stroke-width", 5)    // set the stroke width
    .style("stroke", linecolour)   // set the line colour
    .style("fill", "none");    // set the fill colour 


// draw a rectangle - end zone 2
holder.append("rect")        // attach a rectangle
    .attr("x", 1150)         // position the left of the rectangle
    .attr("y", 50)          // position the top of the rectangle
    .attr("height", 533)    // set the height
    .attr("width", 100)    // set the width
    .style("stroke-width", 5)    // set the stroke width
    .style("stroke", linecolour)    // set the line colour
    .style("fill", "none");    // set the fill colour

// get yard-lines:
holder.selectAll("line")
      .data(incFieldArray)
      .enter().append("line")
                .attr("x1",function(d,i){ return 100+ (d*10); })
                .attr("stroke-width",function(d,i){ if(i%2 !==0) {return "2px"} else {return "1px"}})
                .attr("stroke",linecolour)
                .attr("y1",50)
                .attr("x2",function(d,i){ return 100+ (d*10);  })
                .attr("y2",583);

// Add NFL SVG Logo in the center of the field
holder.append("g").append("svg:image")
    .attr("xlink:href", "https://logotyp.us/file/nfl.svg")
    .attr("width", 100)
    .attr("height", 100)
    .attr("x", 600)
    .attr("y",266);

// Might be nice to add yard line numbers


// Now let us work on plotting the lines:
d3.csv("rushers_500.csv")
        .row(function(d) { return {x1: Number(d.X), x2: Number(d.X1), y1: Number(d.Y), y2: Number(d.Y1), Speed: Number(d.S), Name: d.DisplayName}; })
        .get(function(error,data) {

        var allPlayers = d3.map(data, function(d){return(d.Name)}).keys();
		
       // .transition()
     //   .duration(5000)
     //. delay(function(d, i) { // new delay call.
      // return i*5000;
     //})

     // A function that update the chart
    function update(selectedGroup) {

        console.log(selectedGroup);
		
		//d3.select("#field").selectAll('.vector')
		//.data([]).exit().remove();
		
		d3.select("#field").selectAll('.vector').remove()
		.data(data.filter(function(d){ return d.Name == selectedGroup; }))
		.enter().append('line')
		.attr('class', 'vector')
        .attr("x1", function(d){ return (d.x1*10)+50;} )
        .attr("y1", function(d){ return (d.y1*10)+50;} )
        .attr("x2", function(d){ return (d.x2*10)+50; })
        .attr("y2", function(d){ return (d.y2*10)+50; })
        .attr("stroke", "blue")
        .attr("stroke-width", function(d) { return (d.Speed * 50); });
		
		console.log(d3.select("#field").selectAll('.vector'));
		
      // // Give these new data to update line
      //   holder.selectAll("line")
      //   .data(data)
      //   .enter().append("line")
      //   .filter(function(d) { console.log(d.Name); console.log(selectedGroup); console.log(d.Name == selectedGroup); return d.Name == selectedGroup; })
      //   .attr("x1", function(d){ return (d.x1*10)+50;} )
      //   .attr("y1", function(d){ return (d.y1*10)+50;} )
      //   .attr("x2", function(d){ return (d.x2*10)+50; })
      //   .attr("y2", function(d){ return (d.y2*10)+50; })
      //   .attr("stroke", "blue")
      //   .attr("stroke-width", function(d) { return (d.Speed * 50); });
    }

    // When the button is changed, run the updateChart function
    d3.select("#selectButton").on("change", function(d) {
        // recover the option that has been chosen
        var selectedOption = d3.select(this).property("value")
        // run the updateChart function with this selected option
        update(selectedOption)
    })


})

