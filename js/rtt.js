console = d3.window(div.node()).console;
console.log(data);

var tips = data.tips,
    palette = data.palette;


var rtt_input = div.append("div")
                   .attr("id", "rtt-input")
                   .style("width", 100+"px")
                   .style("height", height+"px")
                   .style("display", "inline-block");

var rttdiv = div.append("div")
                .style("width", width-100+"px")
                .style("height", height+"px")
                //.style("margin-top", "-30px")
                .style("display", "inline-block");

rtt_input.selectAll("input")
  .data(Object.entries(data.palette))
  .enter()
  .append("label")
  .text(function(d) { return d[0]; })
  .append("input")
  .attr("type", "checkbox")
  .attr("checked", true)
  .attr("id", function(d,i) { return i; })
  .attr("for", function(d,i) { return i; });

// FIXME: this is not working yet
d3.select("#rtt-input")
  .selectAll("label")
  .append("br");

var rttsvg = rttdiv.append("svg")
                   .attr("id", "rtt-svg")
                   .attr("width", (width-100)+"px")
                   .attr("height", (height)+"px");

// add margins
var margin = {top: 10, right: 10, bottom: 60, left: 60},
    // dimensions for the graph
    gwidth = width - 100 - margin.left - margin.right,
    gheight = height - margin.top - margin.bottom;
  
var rttg = rttsvg.append("g")
                 .attr("height", gheight+"px")
                 .attr("width", gwidth+"px")
                 .attr("id", "rtt-group")
                 .attr("transform", "translate(" + margin.left + ',' + 
                       margin.top + ")");
                       
// set up plotting scales
var ymax = d3.max(tips, d => +d.div),
    ymin = d3.min(tips, d => +d.div),
    yScale = d3.scaleLinear().domain([ymin, ymax]).range([gheight, 0]);

// parse dates
var dateparser = d3.timeParse("%Y-%m-%d"),
    dates = tips.map(d => dateparser(d.coldate));

// map date range to graph region width
var xScale = d3.scaleLinear()
               .domain(d3.extent(dates))
               .range([0, gwidth]);

// draw points, coloured by PANGO group
var rttplot = rttg.selectAll("circle")
                  .data(tips)
                  .enter();
                  
rttplot.append("circle")
       .attr("cx", function(d, i) { 
         // i is an iteration count
         return xScale(dates[i]); 
       })
       .attr("cy", function(d) { return yScale(d.div); })
       .attr("r", 3)
       .style("stroke", "black")
       .style("fill", "none");       

rttplot.append("circle")
       .attr("cx", function(d, i) { return xScale(dates[i]); })
       .attr("cy", function(d) { return yScale(d.div); })
       .attr("r", 3)
       .style("fill", function(d) {
         if (d.pango in palette) {
           return palette[d.pango][0];
         } else {
           return "#777";
         }
       });

// draw axes labels
var rtt_xaxis = d3.axisBottom(xScale)
                  .tickFormat(function(date) {
                    return d3.timeFormat('%b \'%y')(date);
                  });
                  
rttg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(" + xScale(d3.min(dates)) + 
          "," + gheight + ")")
    .call(rtt_xaxis);

rttsvg.append("text")
      .attr("class", "x label")
      .attr("text-anchor", "middle")
      .attr("x", gwidth/2 + margin.left)
      .attr("y", gheight + margin.top + margin.bottom - 10)
      .text("Sampling date");

