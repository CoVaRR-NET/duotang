// informed by http://emilydolson.github.io/D3-visualising-data/09-d3exit.html

console = d3.window(div.node()).console;
//console.log(data);  // for debugging

// parse dates
var dateparser = d3.timeParse("%Y-%m-%d"),
    fits = data.fits.map(row => ({ ...row, display: true})),
    tips = data.tips.map(
      x => ({ ...x, display: true, coldate: dateparser(x.coldate) })),
    dates = tips.map(d => d.coldate),
    palette = data.palette;


// append entry for "other"
palette["other"] = ["#777777"];

var ri_wide = 130,  // width of input column
    rtt_input = div.append("div")
                   .attr("id", "rtt-input")
                   .style("width", ri_wide+"px")
                   .style("height", height+"px")
                   .style("vertical-align", "top")
                   .style("text-align", "right")
                   .style("display", "inline-block");

var rttdiv = div.append("div")
                .attr("id", "rtt-div")
                .style("width", width-ri_wide+"px")
                .style("height", height+"px")
                //.style("margin-top", "-30px")
                .style("display", "inline-block");

// render checkbox inputs labelled by PANGO group
rtt_input.selectAll("input")
  .data(Object.entries(data.palette))
  .enter()
  .append("label")
  .text(function(d) { return d[0]; })
  .append("input")
  .attr("type", "checkbox")
  .attr("class", "rtt_cb")
  .attr("value", function(d) { return d[0]; })
  .style("accent-color", function(d) { return d[1]; })
  .attr("checked", true)
  .attr("id", function(d,i) { return i; })
  .attr("for", function(d,i) { return i; });

// render inputs on separate lines
rtt_input.selectAll("label")
  .append("br");

// bind event listener to checkboxes
rtt_input.selectAll(".rtt_cb")
  .on("change", function() {
    // check that at least one checkbox is active
    var nchecks = rtt_input.selectAll(".rtt_cb").filter(":checked").size();
    if (nchecks == 0) {
      console.log("Cannot have zero variants checked!")
      console.log(this);
      this.checked = true;
    }
    else {
      // mark points for masking
      var pgroup = tips.filter(x => x.pango == this.value);
      pgroup.map(x => x.display = this.checked);
      
      // mark slopes for masking
      var slope = fits.filter(x => x.pango == this.value);
      slope.map(x => x.display = this.checked);
      rtt_update();      
    }
  })


// prepare SVG for scatterplot
var rttsvg = rttdiv.append("svg")
                   .attr("id", "rtt-svg")
                   .attr("width", (width-ri_wide)+"px")
                   .attr("height", (height)+"px");

// add margins
var margin = {top: 10, right: 10, bottom: 60, left: 60},
    // dimensions for the graph
    gwidth = width - ri_wide - margin.left - margin.right,
    gheight = height - margin.top - margin.bottom;
  
var rttg = rttsvg.append("g")
                 .attr("height", gheight+"px")
                 .attr("width", gwidth+"px")
                 .attr("id", "rtt-group")
                 .attr("transform", "translate(" + margin.left + ',' + 
                       margin.top + ")");
                       
// set up plotting scales
var ymax = d3.max(tips, d => +d.div),
    ymin = d3.min(tips, d => +d.div);

var yScale = d3.scaleLinear()
               .domain([ymin, ymax])
               .range([gheight, 0]);

var yMap = function(d) { return yScale(d.div); },
    yMap1 = function(d) { return Math.min(yScale.range()[0], yScale(d.y1)); },
    yMap2 = function(d) { return yScale(d.y2); };

// map date range to graph region width
var xScale = d3.scaleLinear()
               .domain(d3.extent(dates))
               .range([0, gwidth]);

var xMap = function(d) { return xScale(d.coldate); },
    xMap1 = function(d) { return Math.max(0, xScale(dateparser(d.x1))); },
    xMap2 = function(d) { return xScale(dateparser(d.x2)); };


// draw x-axis (dates)
var rtt_xaxis = d3.axisBottom(xScale)
                  .tickFormat(function(date) {
                    return d3.timeFormat('%b \'%y')(date);
                  });
                  
rttg.append("g")
    .attr("class", "xaxis")
    .attr("transform", "translate(" + xScale(d3.min(dates)) + 
          "," + gheight + ")")
    .call(rtt_xaxis);

rttsvg.append("text")
      .attr("class", "xlabel")
      .attr("text-anchor", "middle")
      .attr("x", gwidth/2 + margin.left)
      .attr("y", gheight + margin.top + margin.bottom - 10)
      .text("Sampling date");

// draw y-axis (divergence)
var rtt_yaxis = d3.axisLeft(yScale);

rttg.append("g")
    .attr("class", "yaxis")
    .call(rtt_yaxis);

// https://gist.github.com/mbostock/4403522
rttsvg.append("text")
      .attr("class", "ylabel")
      .attr("x", 0)
      .attr("y", margin.left - 30)
      .attr("transform", "translate(0,"+(gheight/2)+")rotate(-90)")
      .attr("text-anchor", "middle")
      .text("Divergence from root");

// draw points
rttg.selectAll("circle")
    .data(tips)
    .enter()
    .append("circle")
    //.filter(function(d) { return d.display; })
    .attr("cx", xMap)
    .attr("cy", yMap)
    .attr("r", 3)
    .style("fill", function(d) {
     if (d.pango in palette) {
       return palette[d.pango];
     } else {
       return "#777";
     }
    });

// draw lines

rttg.selectAll("lines")
    .data(fits)
    .enter()
    .append("line")
    .attr("class", "slopesOutline")
    .attr("x1", xMap1)
    .attr("y1", yMap1)
    .attr("x2", xMap2)
    .attr("y2", yMap2)
    .attr("stroke-width", 6)
    .attr("stroke", "white");
	
rttg.selectAll("lines")
    .data(fits)
    .enter()
    .append("line")
    .attr("class", "slopes")
    .attr("x1", xMap1)
    .attr("y1", yMap1)
    .attr("x2", xMap2)
    .attr("y2", yMap2)
    .attr("stroke-width", 3)
    .attr("stroke", function(d) { return palette[d.pango]; });

function rtt_update() {
  // recalculate plot region
  var filtered = tips.filter(x => x.display);
  dates = filtered.map(x => x.coldate);
  xScale.domain(d3.extent(dates));
  ymax = d3.max(filtered, d => +d.div),
  ymin = d3.min(filtered, d => +d.div);
  yScale.domain([ymin, ymax]);
  
  // update axes
  rttg.select(".xaxis")
      .transition().duration(500)
      .call(rtt_xaxis);
  rttg.select(".yaxis")
      .transition().duration(500)
      .call(rtt_yaxis);
  
  // update points
  rttg.selectAll("circle")
      .transition().duration(500)
      .attr("r", function(d) { return d.display ? 3 : 0; } )
      .attr("cx", xMap)
      .attr("cy", yMap);
  
  // update regression lines
rttg.selectAll(".slopesOutline")
      .transition().duration(500)
      .attr("x1", xMap1)
      .attr("y1", yMap1)
      .attr("x2", xMap2)
      .attr("y2", yMap2)
      .attr("stroke-width", function(d) { return d.display ? 6 : 0; });
  rttg.selectAll(".slopes")
      .transition().duration(500)
      .attr("x1", xMap1)
      .attr("y1", yMap1)
      .attr("x2", xMap2)
      .attr("y2", yMap2)
      .attr("stroke-width", function(d) { return d.display ? 3 : 0; });
}


