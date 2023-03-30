// informed by http://emilydolson.github.io/D3-visualising-data/09-d3exit.html

console = d3.window(div.node()).console;
console.log(data);

var tips = data.tips.map(x => ({ ...x, display: true })),
    //filtered_tips = tips, 
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
  .style("accent-color", function(d) { return d[1][0]; })
  .attr("checked", true)
  .attr("id", function(d,i) { return i; })
  .attr("for", function(d,i) { return i; });

// render inputs on separate lines
rtt_input.selectAll("label")
  .append("br");


// bind event listener to checkboxes
rtt_input.selectAll(".rtt_cb")
  .on("change", function() {
    var pgroup = tips.filter(x => x.pango == this.value);
    pgroup.map(x => x.display = this.checked);
    
    /*
    if (this.checked) {
      // restore group from original data
      filtered_tips = filtered_tips.concat(pgroup);
    } else {
      // remove group from data
      filtered_tips = filtered_tips.filter(x => x.pango != this.value);
    }
    */
    
    //console.log(filtered_tips);
    //console.log(tips);
    rtt_update();
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
    ymin = d3.min(tips, d => +d.div),
    yScale = d3.scaleLinear().domain([ymin, ymax]).range([gheight, 0]);

// parse dates
var dateparser = d3.timeParse("%Y-%m-%d"),
    dates = tips.map(d => dateparser(d.coldate));

// map date range to graph region width
var xScale = d3.scaleLinear()
               .domain(d3.extent(dates))
               .range([0, gwidth]);


//rtt_update();


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

var rttplot = rttg.selectAll("circle")
                  .data(tips);
rttplot.enter()
       .append("circle")
       //.filter(function(d) { return d.display; })
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

function rtt_update() {
  console.log("update");
  //console.log(rttplot);
  rttplot.selectAll("circle")
                   .data(tips)
                   .attr("r", function(d) {return 2;});
  /*
  rttplot.selectAll("circle")
       .data(tips)
       .attr("r", function(d) d.display ? 3 : 0);
       */
       
  //dates = filtered_tips.map(d => dateparser(d.coldate));

                  
  //rttplot.enter().append("circle").attr("class", "data_point");
  
  
  /*
  rttplot.attr("cx", function(d, i) { 
           // i is an iteration count
           return xScale(dates[i]); 
         })
         .attr("cy", function(d) { return yScale(d.div); })
         .attr("r", 3)
         .style("stroke", "black")
         .style("fill", "none");
  */

  //rttplot.exit().remove();
}


