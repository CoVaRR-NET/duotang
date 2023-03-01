console = d3.window(div.node()).console;
console.log(data);

var dateparser = d3.timeParse("%Y-%m-%d");

var rttdiv = div.append("div")
                .style("width", (width-100)+"px")
                .style("height", (height-100)+"px")
                .style("margin-top", "-30px")
                .style("display", "inline-block");

var rttsvg = rttdiv.append("svg")
                   .attr("id", "rtt-svg")
                   .attr("width", (width-100)+"px")
                   .attr("height", (height-100)+"px");

// add margins
var margin = {top: 10, right: 10, bottom: 10, left: 10},
    gwidth = width - 100 - margin.left - margin.right,
    gheight = height - 100 - margin.top - margin.bottom;
  
var rttg = rttsvg.append("g")
                 .attr("height", gheight+"px")
                 .attr("width", gwidth+"px")
                 .attr("id", "rtt-group")
                 .attr("transform", "translate(" + margin.left + ',' + 
                       margin.tip + ")");
                       
// set up plotting scales
var ymax = d3.max(data, d => +d.div),
    ymin = d3.min(data, d => +d.div),
    yScale = d3.scaleLinear().domain([ymin, ymax]).range([gheight, 40]),

dates = data.map(d => dateparser(d.coldate));

var xScale = d3.scaleLinear()
               .domain(d3.extent(dates))
               .range([0, (gwidth-100) ]);

var rttplot = rttg.selectAll("circle")
                  .data(data)
                  .enter().append("circle")
                  .attr("cx", function(d) { return xScale(dateparser(d.coldate)); })
                  .attr("cy", function(d) { return yScale(d.div); })
                  .attr("r", 3)
                  .style("fill", "black");