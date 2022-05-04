console = d3.window(svg.node()).console;
console.log(data);

var margin = {top: 40, right: 10, bottom: 20, left: 10},
    width = width - margin.left - margin.right,
    height = height - margin.top - margin.bottom,
    g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

var labels = Object.keys(data[0]),
    variants = labels.filter(w => w!=="week");

var n = variants.length,  // number of categories
    m = data.length;  // number of observations (time points)

const stack = d3.stack().keys(variants);
const series = stack(data);


var ymax = d3.max(series, function(y) { 
  return d3.max(y, function(d) { return d[1]; }) 
});

var weeks = data.map(x => new Date(x.week));


var xScale = d3.scaleTime()
          .domain([weeks[0], weeks[m-1]])
          .range([0, width]),
    yScale = d3.scaleLinear()
          .domain([0, ymax])
          .range([height, 0]),
    bandwidth = xScale(weeks[1]) - xScale(weeks[0]);

var color = d3.scaleOrdinal()
    .domain(variants)
    .range(["#9AD378", "#B29C71", "#3EA534", "#F08C3A", "#A6CEE3", "#61A6A0", 
            "#438FC0", "#444444", "#CD950C", "#BB4513", "#8B0000", "#FA8072",
            "#FF0000", "#888888"]);


var barplot = svg.append("g").selectAll(".series")
  .data(series)
  .enter().append("g")
    .attr("fill", function(d, i) { return color(i); });


var rect = barplot.selectAll("rect")
  .data(function(d) { return d; })
  .enter().append("rect")
    .attr("x", function(d, i) { return xScale(weeks[i]); })
    .attr("width", bandwidth)
    .attr("y", function(d) { return yScale(d[1]); })
    .attr("height", function(d) { return yScale(d[0]) - yScale(d[1]); });

