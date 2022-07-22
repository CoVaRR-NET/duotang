/**
 * Inspired by https://observablehq.com/@d3/streamgraph-transitions
 * 
 *  r2d3 passes a `data` object to this JavaScript, as well as a 
 *  reference to a <div> element in the Rmarkdown document 
 *  with a predefined `width` and `height`.
 * 
 *  Note about scoping:  objects from r2d3 are, by default, embedded
 *  within a shadow DOM.  d3.select() will not be able to find elements
 *  within this DOM.  To select those elements, you need to do a search 
 *  from div, i.e., div.select()
 */

// this is required to pass messages to JavaScript console
console = d3.window(div.node()).console;

// create drop-down menu to select stacked plot offset
const opts = [
  {name: "basic", value: "d3.stackOffsetNone"},
  {name: "percent", value: "d3.stackOffsetExpand"},
  {name: "silhouette", value: "d3.stackOffsetSilhouette", selected: true},
  {name: "streamgraph", value: "d3.stackOffsetWiggle"}
];

var selectlabel = div.append('label').text("Layout: ");

var selector = selectlabel.append('select')
                 .attr('class', 'select')
                 .attr('id', 'offset-select')
                 .on('change', function(event) {
                   //var myChoice = event.target.selectedOptions[0];
                   //console.log(myChoice);
                   //updateBarplot(offsets[myChoice.value]);  // redraw
                   updateBarplot();
                 });

var choices = selector.selectAll("option")
                      .data(opts).enter()
                      .append('option')
                      .text(function(d) { return d.name; })
                      .attr("value", function(d) { return d.value; })
                      .attr("selected", function(d) {return d.selected; });

// append another drop-down for region
const opts2 = [
  {name: "Canada", value: "Canada", selected: true},
  {name: "British Columbia", value: "British Columbia"},
  {name: "Alberta", value: "Alberta"},
  {name: "Saskatchewan", value: "Saskatchewan"},
  {name: "Manitoba", value: "Manitoba"},
  {name: "Ontario", value: "Ontario"},
  {name: "Quebec", value: "Quebec"},
  {name: "New Brunswick", value: "New Brunswick"},
  {name: "Newfoundland and Labrador", value: "Newfoundland and Labrador"},
  {name: "Nova Scotia", value: "Nova Scotia"}
];

var selectlabel2 = div.append('label').text("  Region: "),
    selector2 = selectlabel2.append('select')
                 .attr('class', 'select')
                 .attr('id', 'region-select')
                 .on('change', function(event) {
                   updateBarplot();  // redraw
                 }),
    choices2 = selector2.selectAll("option")
                        .data(opts2).enter()
                        .append('option')
                        .text(function(d) { return d.name; })
                        .attr("value", function(d) { return d.value; })
                        .attr("selected", function(d) {return d.selected; });

// draw legend box
// https://d3-graph-gallery.com/graph/custom_legend.html
const palette = data["legend"];
delete(data.legend);
var legend = div.append("svg")
                .attr("width", div.attr("width"))
                .attr("height", "70px");

legend.selectAll("mydots")
      .data(Object.entries(palette))
      .enter().append("circle")
      .attr("cx", function(d, i) { return (i%5)*120 + 50; })
      .attr("cy", function(d, i) { return Math.floor(i/5)*20 + 10; })
      .attr("r", 6)
      .style("fill", function(d) { return d[1]; } );
      
legend.selectAll("mylabels")
      .data(Object.entries(palette))
      .enter().append("text")
      .attr("x", function(d, i) { return (i%5)*120 + 60; })
      .attr("y", function(d, i) { return Math.floor(i/5)*20 + 10; })
      .text(function(d) { return d[0]; })
      .style("alignment-baseline", "middle")
      .style("font-size", "8pt");
      
// append an SVG element to the div
var plotheight = 480,
    bpsvg = div.append("svg")
        .attr("width", width+"px")        
        .attr("height", plotheight+"px")

// append a new group to SVG with nice margins (where axis labels are drawn)
var margin = {top: 0, right: 50, bottom: 20, left: 50},
    width = width - margin.left - margin.right,
    height = plotheight - margin.top - margin.bottom,
    g = bpsvg.append("g")
           .attr("height", plotheight+"px")
           .attr("id", "barplot-group")
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
    variants = labels.filter(w => w!=="_row");

var n = variants.length,  // number of categories
    m = data["Canada"].length;  // number of observations (time points)

// generate stacked series from data
var stack = d3.stack().keys(variants).offset(d3.stackOffsetSilhouette),
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

// allow browser to resize height of this section to accommodate SVGs
//d3.select("#barplot-element").style("height", "600px");


function absolutePosition(el) {
  // https://stackoverflow.com/questions/25630035/javascript-getboundingclientrect-changes-while-scrolling
    var top = 0,
        offsetBase = absolutePosition.offsetBase;
    if (!offsetBase && document.body) {
        offsetBase = absolutePosition.offsetBase = document.createElement('div');
        offsetBase.style.cssText = 'position:absolute;left:0;top:0';
        document.body.appendChild(offsetBase);
    }
    if (el && el.ownerDocument === document && 'getBoundingClientRect' in el && 
        offsetBase) {
        var boundingRect = el.getBoundingClientRect();
        var baseRect = offsetBase.getBoundingClientRect();
        top = boundingRect.top - baseRect.top;
    }
    return top;
}

var xScale = d3.scaleTime()
          .domain([weeks[0], weeks[m-1]])
          .range([0, width]),
    yScale = d3.scaleLinear()
          .domain([ymin, ymax])
          .range([height, 0]),
    bandwidth = xScale(weeks[1]) - xScale(weeks[0]),
    xtime,
    yoffset = absolutePosition(bpsvg.node());

console.log(bpsvg);
console.log(yoffset);

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
bpsvg.selectAll(".layer")
    .attr("opacity", 1)
    .on("mouseover", function(event, datum) {
      d3.select(this)
        .classed("hover", true)
        .attr("stroke", "#000000")
        .attr("stroke-width", "0.5px");
        
      bpsvg.selectAll(".layer").transition()
         .duration(250)
         .attr("opacity", function(d, j) {
           return j != datum.index ? 0.5 : 1;
         })
    })
    .on("mousemove", function(event, datum) {
      coords = d3.pointer(event);
      console.log(coords);
      //xtime = xScale.invert(event.x);
      xtime = xScale.invert(coords[0]);
      week = d3.bisect(weeks, xtime);
      
      tooltip.html( "<p>" + datum.key + "<br/>" + datum[week].data[datum.key] + "</p>" )
             .style("visibility", "visible")
             .style("left", (coords[0] + 100) + "px")
             .style("top", (coords[1] + yoffset - 50) + "px");
    })
    .on("mouseout", function(event, datum) {
      d3.select(this)
        .classed("hover", false)
        .attr("stroke-width", "0");
      tooltip.style("visibility", "hidden");
        
      bpsvg.selectAll(".layer")
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

// bind option values to function calls
const offsets = {
  "d3.stackOffsetExpand": d3.stackOffsetExpand,
  "d3.stackOffsetNone": d3.stackOffsetNone,
  "d3.stackOffsetSilhouette": d3.stackOffsetSilhouette,
  "d3.stackOffsetWiggle": d3.stackOffsetWiggle,
};

function updateBarplot() {
  var offset = div.select("select#offset-select").property("value"),
      offsetf = offsets[offset],
      region = div.select("select#region-select").property("value");
  
  stack = d3.stack().keys(variants).offset(offsetf);
  series = stack(data[region]);  // TODO: change data set here
  
  // modify vertical scale
  ymin = d3.min(series, function(y) { 
    return d3.min(y, function(d) { return d[0]; }) 
  });
  ymax = d3.max(series, function(y) { 
    return d3.max(y, function(d) { return d[1]; }) 
  });
  yScale = d3.scaleLinear().domain([ymin, ymax])
          .range([height, 0]);
  
  bpsvg.select("g.yl_axis").transition()
     .duration(500)
     .call(d3.axisLeft(yScale));
  bpsvg.select("g.yr_axis").transition()
     .duration(500)
     .call(d3.axisRight(yScale));
  
  barplot.data(series)
         .transition()
         .duration(500)
         .attr("d", area)
         .attr("fill", function(d, i) { return color(i); });
}
