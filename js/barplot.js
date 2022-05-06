/**
 * Inspired by https://observablehq.com/@d3/streamgraph-transitions
 * 
 *  r2d3 passes a `data` object to this JavaScript, as well as a 
 *  reference to a <div> element in the Rmarkdown document 
 *  with a predefined `width` and `height`.
 */

// this is required to pass messages to JavaScript console
console = d3.window(div.node()).console;

// create drop-down menu to select stacked plot offset
const opts = [
  {name: "basic", value: "d3.stackOffsetNone"},
  {name: "percent", value: "d3.stackOffsetExpand"},
  {name: "silhouette", value: "d3.stackOffsetSilhouette"},
  {name: "streamgraph", value: "d3.stackOffsetWiggle", selected: true}
];

// bind option values to function calls
const offsets = {
  "d3.stackOffsetExpand": d3.stackOffsetExpand,
  "d3.stackOffsetNone": d3.stackOffsetNone,
  "d3.stackOffsetSilhouette": d3.stackOffsetSilhouette,
  "d3.stackOffsetWiggle": d3.stackOffsetWiggle,
};

var selectlabel = div.append('label').text("Layout: ");

var selector = selectlabel.append('select')
                 .attr('class', 'select')
                 .on('change', function(event) {
                   var myChoice = event.target.selectedOptions[0];
                   //console.log(myChoice);
                   updateBarplot(offsets[myChoice.value]);  // redraw
                 });

var choices = selector.selectAll("option")
                      .data(opts).enter()
                      .append('option')
                      .text(function(d) { return d.name; })
                      .attr("value", function(d) { return d.value; })
                      .attr("selected", function(d) {return d.selected; });

// append an SVG element to the div
var svg = div.append("svg")
        .attr("width", div.attr("width"))
        .attr("height", div.attr("height"));

// append a new group to SVG with nice margins (where axis labels are drawn)
var margin = {top: 5, right: 50, bottom: 20, left: 50},
    width = width - margin.left - margin.right,
    height = height - margin.top - margin.bottom,
    g = svg.append("g")
           .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

// append tooltip element
var tooltip = div.append("div")
    .attr("class", "tooltip")
    .attr("id", "tooltipContainer")
    .style("position", "absolute")
    .style("z-index", "20")
    .style("visibility", "hidden")
    .style("pointer-events", "none");

// extract variant names, e.g., "Omicron (BA.1)"
var labels = Object.keys(data["Canada"][0]),
    variants = labels.filter(w => w!=="_row"),
    palette = {  // mapped to variants in alphabetical order
      "A.23.1": "#9AD378", 
      "Alpha": "#B29C71", 
      "B.1.438.1": "#3EA534", 
      "Beta": "#F08C3A", 
      "Delta": "#A6CEE3", 
      "Delta AY.25": "#61A6A0", 
      "Delta AY.27": "#438FC0", 
      "Gamma": "#444444", 
      "Lambda": "#CD950C", 
      "Mu": "#BB4513", 
      "Omicron BA.1": "#8B0000", 
      "Omicron BA.1.1": "#FA8072",
      "Omicron BA.2": "#FF0000", 
      "other": "#888888"
    };

var n = variants.length,  // number of categories
    m = data["Canada"].length;  // number of observations (time points)

// generate stacked series from data
var stack = d3.stack().keys(variants).offset(d3.stackOffsetWiggle),
    series = stack(data["Canada"]);

// vertical limits
var ymin = d3.min(series, function(y) { 
                  return d3.min(y, function(d) { return d[0]; })
                }),
    ymax = d3.max(series, function(y) { 
                  return d3.max(y, function(d) { return d[1]; }) 
                });

var weeks = data["Canada"].map(x => new Date(x._row)),
    week;


var xScale = d3.scaleTime()
          .domain([weeks[0], weeks[m-1]])
          .range([0, width]),
    yScale = d3.scaleLinear()
          .domain([ymin, ymax])
          .range([height, 0]),
    bandwidth = xScale(weeks[1]) - xScale(weeks[0]),
    xtime,
    yoffset = document.getElementById("barplot-element").getBoundingClientRect().y;


var color = d3.scaleOrdinal()
    .domain(variants)
    .range(variants.map(v => palette[v]));

// draws shapes with interpolation between data points (curve)
var area = d3.area()
    .x(function(d, i) { return xScale(weeks[i]); })
    .y0(function(d) { return yScale(d[0]); })
    .y1(function(d) { return yScale(d[1]); })
    .curve(d3.curveBasis);

var barplot = g.selectAll("path")
                 .data(series)
                 .enter().append("path")
                 .attr("class", "layer")
                 .attr("d", area)
                 .attr("fill", function(d, i) { return color(i); });

// http://bl.ocks.org/WillTurman/4631136
svg.selectAll(".layer")
    .attr("opacity", 1)
    .on("mouseover", function(event, datum) {
      d3.select(this)
        .classed("hover", true)
        .attr("stroke", "#000000")
        .attr("stroke-width", "0.5px");
        
      svg.selectAll(".layer").transition()
         .duration(250)
         .attr("opacity", function(d, j) {
           return j != datum.index ? 0.5 : 1;
         })
    })
    .on("mousemove", function(event, datum) {
      coords = d3.pointer(event);
      //xtime = xScale.invert(event.x);
      xtime = xScale.invert(coords[0]);
      week = d3.bisect(weeks, xtime);
      
      tooltip.html( "<p>" + datum.key + "<br/>" + datum[week].data[datum.key] + "</p>" )
             .style("visibility", "visible")
             .style("left", (coords[0] + 30) + "px")
             .style("top", (coords[1] + yoffset - 20) + "px");
    })
    .on("mouseout", function(event, datum) {
      d3.select(this)
        .classed("hover", false)
        .attr("stroke-width", "0");
      tooltip.style("visibility", "hidden");
        
      svg.selectAll(".layer")
         .transition()
         .duration(100)
         .attr("opacity", "1");
    });

// draw x-axis labels
var xAxis = d3.axisBottom(xScale)
              .tickFormat(function(date){
                 if (d3.timeYear(date) < date) {
                   // abbreviate months (October to Oct)
                   return d3.timeFormat('%b')(date);
                 } else {
                   return d3.timeFormat('%Y')(date);
                 }
              });
              
g.append("g")
   .attr("class", "x axis")
   .attr("transform", "translate(0," + height + ")")
   .call(xAxis);

  
// draw y-axis
g.append("g")
   .attr("class", "yl_axis")
   .attr("transform", "translate(0, 0)")
   .call(d3.axisLeft(yScale));
g.append("g")
   .attr("class", "yr_axis")
   .attr("transform", "translate(" + width + ", 0)")
   .call(d3.axisRight(yScale));

function updateBarplot(offset) {
  stack = d3.stack().keys(variants).offset(offset);
  series = stack(data["Canada"]);  // TODO: change data set here
  
  // modify vertical scale
  ymin = d3.min(series, function(y) { 
    return d3.min(y, function(d) { return d[0]; }) 
  });
  ymax = d3.max(series, function(y) { 
    return d3.max(y, function(d) { return d[1]; }) 
  });
  yScale = d3.scaleLinear().domain([ymin, ymax])
          .range([height, 0]);
  
  svg.select("g.yl_axis").transition()
     .duration(500)
     .call(d3.axisLeft(yScale));
  svg.select("g.yr_axis").transition()
     .duration(500)
     .call(d3.axisRight(yScale));
  
  barplot.data(series)
         .transition()
         .duration(500)
         .attr("d", area)
         .attr("fill", function(d, i) { return color(i); });
}
