console = d3.window(div.node()).console;
//console.log(data);


// create drop-down menu to select stacked plot offset
const opts = [
  {name: "expand", value: "d3.stackOffsetExpand"},
  {name: "none", value: "d3.stackOffsetNone"},
  {name: "silhouette", value: "d3.stackOffsetSilhouette"},
  {name: "wiggle", value: "d3.stackOffsetWiggle", selected: true}
];

const offsets = {
  "d3.stackOffsetExpand": d3.stackOffsetExpand,
  "d3.stackOffsetNone": d3.stackOffsetNone,
  "d3.stackOffsetSilhouette": d3.stackOffsetSilhouette,
  "d3.stackOffsetWiggle": d3.stackOffsetWiggle,
};

var selector = div.append('select')
                 .attr('class', 'select')
                 .on('change', function(event) {
                   var myChoice = event.target.selectedOptions[0];
                   console.log(myChoice);
                   updateBarplot(offsets[myChoice.value]);  // pass function
                 });

var choices = selector.selectAll("option")
                      .data(opts).enter()
                      .append('option')
                      .text(function(d) { return d.name; })
                      .attr("value", function(d) { return d.value; });


var svg = div.append("svg")
        .attr("width", div.attr("width"))
        .attr("height", div.attr("height"));



var margin = {top: 40, right: 10, bottom: 20, left: 10},
    width = width - margin.left - margin.right,
    height = height - margin.top - margin.bottom,
    g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

var labels = Object.keys(data[0]),
    variants = labels.filter(w => w!=="week"),
    palette = ["#9AD378", "#B29C71", "#3EA534", "#F08C3A", "#A6CEE3", "#61A6A0", 
            "#438FC0", "#444444", "#CD950C", "#BB4513", "#8B0000", "#FA8072",
            "#FF0000", "#888888"];

var n = variants.length,  // number of categories
    m = data.length;  // number of observations (time points)

var stack = d3.stack().keys(variants),
    series = stack(data);


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
    .range(palette);

var area = d3.area()
    .x(function(d, i) { return xScale(weeks[i]); })
    .y0(function(d) { return yScale(d[0]); })
    .y1(function(d) { return yScale(d[1]); })
    .curve(d3.curveBasis);

var barplot = svg.append("g")
                 .selectAll("path")
                 .data(series)
                 .enter().append("path")
                 .attr("d", area)
                 .attr("fill", function(d, i) { return color(i); });

function updateBarplot(offset) {
  stack = d3.stack().keys(variants).offset(offset);
  series = stack(data);
  console.log(series);
  barplot.data(series)
         .transition()
         .duration(2000)
         .attr("d", area)
         .attr("fill", function(d, i) { return color(i); });
}
