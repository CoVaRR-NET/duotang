//console.log(Object.keys(data[0]));
var groups = data.map(x => x.week),
    subgroups = Object.keys(data[0]).filter(x => x!=="week");

// Add X axis
var x = d3.scaleBand()
    .domain(groups)
    .range([0, width])
    .padding([0.2]);

svg.append("g")
  .attr("transform", "translate(0," + height + ")")
  .call(d3.axisBottom(x).tickSizeOuter(0));

// Add Y axis
var y = d3.scaleLinear()
  .domain([0, 100])
  .range([ height, 0 ]);

svg.append("g")
  .call(d3.axisLeft(y));

var color = d3.scaleOrdinal()
    .domain(subgroups)
    .range(['#e41a1c','#377eb8','#4daf4a']);

var stackedData = d3.stack()
    .keys(subgroups)
    (data);

svg.append("g")
    .selectAll("g")
    // Enter in the stack data = loop key per key = group per group
    .data(stackedData)
    .enter().append("g")
      .attr("fill", function(d) { return color(d.key); })
      .selectAll("rect")
      // enter a second time = loop subgroup per subgroup to add all rectangles
      .data(function(d) { return d; })
      .enter().append("rect")
        .attr("x", function(d) { return x(d.data.group); })
        .attr("y", function(d) { return y(d[1]); })
        .attr("height", function(d) { return y(d[0]) - y(d[1]); })
        .attr("width",x.bandwidth());
