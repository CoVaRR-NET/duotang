/**
 * Justin Jia https://github.com/bfjia
 * Based on initial prototype by Art Poon https://github.com/ArtPoon
 * Based on drawtree.js from https://github.com/PoonLab/CoVizu
 * Initial release 2022/11/27
 * 
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 * Required input variables rom R: `data`, `div`, `height`, and `width` .
 * 
 *  `data` is a json object with two entries, `nodes` and `edges`. Pass in with r2d3() as the data parameter.
*         `edges` is a json array. E.g. {parent: 9429, child: 9430, length: 0.0095, isTip: false, x0: 0, …}
*         `nodes` is an json array. E.g. {label: 'hCoV-19/Canada/...', n.tips: 0, x: 0.2423, y: 1} 
*               ^This object isnt actually used due to performance issues with rendering the tree.
 *  `div` is the HTML frame that the tree will be drawn on. Passed in with the r2d3() function in R as the container parameter
 *  `height` and `width` is the div height and width. Automatically passed in with the r2d3() function in R
 */
console = d3.window(div.node()).console;
//console.log(data)

//set the default color scheme
if (data.defaultColorBy == null){var defaultColorBy = "pango_group"}
else{defaultColorBy = data.defaultColorBy[0]}
//sets the default colors. 
var defaultColorList = ["#A6CEE3", "#1F78B4",  "#33A02C", "#FB9A99", "#E31A1C", "#FDBF6F","#B2DF8A", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99", "#B15928"];
var presetColors = {}
for(var i = 0; i < data.VOCVOI.length; i++){
  presetColors[data.VOCVOI[i].name] = data.VOCVOI[i].color
} 
//sets scaling factors
var scalingFactors = {
  "timetree": 1,
  "mltree": 1,
  "omimltree": 1,
  "recombtimetree": 1,
};
var axisOrientations ={
  "timetree": 1,
  "mltree": 0,
  "omimltree": 0,
  "recombtimetree": 1,
}
var scalingFactor = scalingFactors[data.treetype] || 1
var axisOrientation = axisOrientations[data.treetype] || 0

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

/* #region Variable/HTML region definitions */
//Define divs used for elements of the plot
var tdiv = div.append("div") //div for the time axis label?
              .style("width", (width-100)+"px")
              .style("height", "30px")
              .style("position", "relative")
              .style("z-index", "999")
              .style("margin-left", "100px"),
    ldiv = div.append("div") //div for the left static image
              .style("width", "100px")
              .style("height", (height-100)+"px")
              .style("float", "left")
              .style("margin-top", "-30px")
              .style("display", "inline-block"),
    rdiv = div.append("div") //div for the interactive tree
              .style("width", (width-100)+"px")
              .style("height", (height-100)+"px")
              .style("margin-top", "-30px")
              .style("display", "inline-block")
              .style("overflow-x", "hidden")
              .style("overflow-y", "scroll"),
    colorByDiv = div.append("div") //div for the options menu containing dropdown for metadata columns
              .style("width", "165px")
              .style("height", 100+"px")
              .style("margin-left", "110px")
              .style("overflow-x", "hidden")
              .style("overflow-y", "hidden")
              .style("position", "relative")
              .text("Colour Scheme:"),
    optionDiv = div.append("div") //div for the options menu containing checkboxes for unique metadata values
              .style("width", (220) + "px")
              .style("height", 100+"px")
              .style("margin-left", "280px")
              .style("margin-top", -100 + "px")
              .style("overflow-x", "hidden")
              //.style("overflow-y", "hidden")
              .style("position", "relative")
              .attr("id", "optionsDiv"),
    legendDiv = div.append("div") //div for the legend box
              .style("width", (width - 110 - 165-220) + "px")
              .style("height", 100+"px")
              .style("margin-left", "500px")
              .style("margin-top", -100 + "px")
              .style("overflow-x", "hidden")
              //.style("overflow-y", "hidden")
              .style("position", "relative")
              .attr("id", "legendDiv");
       
//define SVG htmls that can be drawn
var lsvg = ldiv.append("svg") //static tree svg
              .attr("id", "left-tree-svg")
              .attr("width", "100px")
              .attr("height", height+"px"),
    topsvg = tdiv.append("svg") //time axis svg
              .attr("height", 25+"px")
              .attr("width", (width-100)+"px");
//    legendsvg = legendDiv.append("svg")
//          .attr("width", (width - 110 - 165-220)+"px")
//          .attr("height", "600px");
          
          //.attr("height", ((((coloredGroups.length) + 1 )* 20 ) + 10)+"px"); 

var treeheight = 4800,  // px
    svg = rdiv.append("svg") //interactive tree svg
              .attr("id", "main-tree-svg")
              .attr("width", (width-100)+"px")
              .attr("height", treeheight+"px");

// add margins
var margin = {top: 10, right: 10, bottom: 10, left: 10},
    gwidth = width - 100 - margin.left - margin.right,
    gheight = treeheight - margin.top - margin.bottom,
    lgheight = height - margin.top - margin.bottom;

//define graphic elements
var g = svg.append("g")
           .attr("height", gheight+"px")
           .attr("width", gwidth+"px")
           .attr("id", "treeplot-group")
           .attr("transform", "translate(" + margin.left + "," + 
                 margin.top + ")");

var lg = lsvg.append("g")
             .attr("height", lgheight+"px")
             .attr("width", "100px")
             .attr("id", "scroll-tree")
             .attr("transform", "translate(" + margin.left + ',' + 
                   margin.top + ")");

var tg = topsvg.append("g")
               .attr("width", gwidth+"px")
               .attr("transform", "translate(" + margin.left + ",0)");
 
// create scrolling rect in left panel
var scrollbox = document.createElementNS("http://www.w3.org/2000/svg", "rect");
scrollbox.setAttribute("width", "100px");
scrollbox.setAttribute("height", ((height-100)/treeheight * lgheight)+"px");
scrollbox.setAttribute("fill", "#00000055")
lsvg.node().append(scrollbox);

// bind event handler to rdiv scroll-tree
rdiv.on("scroll", function(e) {
    scrollbox.setAttribute("y", this.scrollTop/treeheight * height);
});

// append tooltip element
var tooltip = div.append("div")
    .attr("class", "tooltip")
    .attr("id", "tooltipContainer")
    .style("position", "absolute")
    .style("z-index", "20")
    .style("padding", "6px")
    .style("background", "#eee")
    .style("border", "1px solid #aaa")
    .style("border-radius", "8px")
    .style("visibility", "hidden")
    .style("pointer-events", "none");

// set up plotting scales
var xmax = d3.max(data.edges, e => +e.x1),
    ntips = data.nodes.filter(x => x['n.tips'] == 0).length,
    xScale = d3.scaleLinear().domain([0, xmax]).range([0, (gwidth-100) ]),
    yScale = d3.scaleLinear().domain([0, ntips]).range([gheight, 40]),
    xlScale = d3.scaleLinear().domain([0, xmax]).range([0, 100 ]),
    ylScale = d3.scaleLinear().domain([0, ntips]).range([lgheight, 0]),
    yoffset = absolutePosition(svg.node());

/* #endregion */
//function called when the div needs to be re-rendered due to an update
//`drawNodes` is a flag for drawing circles at the tip of the branches. Defaults to false.
function updateTree(drawNodes = false) {
  //remove all existing objects already drawn.
  g.selectAll("*").remove();
  lg.selectAll("*").remove();
  legendDiv.selectAll("*").remove();

  //render the big tree
  var treeplot = g.selectAll("lines")
                  .data(data.edges)
                  .enter().append("line")
                  .attr("class", "lines")
                  .attr("x1", function(d) { return xScale(d.x0); })
                  .attr("x2", function(d) { return xScale(d.x1); })
                  .attr("y1", function(d) { return yScale(d.y0); })
                  .attr("y2", function(d) { return yScale(d.y1); })
                  .attr("stroke-width", 1.0)
                  .attr("stroke", function(d) { return d.colour; })
                  .on("mouseover", function(e, d) {
                      if (d.isTip) {
                          coords = d3.pointer(e);
                          let pos = d3.select(this).node().getBoundingClientRect();
                          //populate the popout box text with ALL metadata columns
                          var toolTipText = "<p>"  
							for(var i = 0; i < metadataFields.length; i++){
							  cleanName = metadataFields[i].charAt(0).toUpperCase() + metadataFields[i].slice(1);
							  cleanName = cleanName.split('_').join(' ');
							  toolTipText = toolTipText + "<b>" + cleanName + `: </b>${d[metadataFields[i]]}<br/>` 
							}
                          toolTipText = toolTipText + "</p>";
                          tooltip.html(toolTipText)
                              .style("visibility", "visible")
                              .style("left", (coords[0] ) + "px")
                              .style('top', `${(window.pageYOffset  + pos['y'] +15)}px`);
                      }
                  })
                  .on("mouseout", function(e, d) {
                    tooltip.style("visibility", "hidden");
                  })
  
  //render the tip node circles
  if (drawNodes){
    var treeplot = g.selectAll("circle")
    .data(data.tips)
    .enter().append("circle")
    .attr("cx",function(d) { return xScale(d.x1); })
    .attr("cy",function(d) { return yScale(d.y1); })
    .attr("r", 3)
    .style("fill", function(d) { return d.colour; })
    .on("mouseover", function(e, d) {
        if (d.isTip) {
            coords = d3.pointer(e);
            let pos = d3.select(this).node().getBoundingClientRect();
            //populate the popout box text with ALL metadata columns
            var toolTipText = "<p>"  
            for(var i = 0; i < metadataFields.length; i++){
              cleanName = metadataFields[i].charAt(0).toUpperCase() + metadataFields[i].slice(1);
              cleanName = cleanName.split('_').join(' ');
              toolTipText = toolTipText + "<b>" + cleanName + `: </b>${d[metadataFields[i]]}<br/>` 
            }
            toolTipText = toolTipText + "</p>";
            tooltip.html(toolTipText)
              .style("visibility", "visible")
              .style("left", (coords[0] ) + "px")
              .style('top', `${(window.pageYOffset  + pos['y'] +15)}px`);
        }
    })
    .on("mouseout", function(e, d) {
      tooltip.style("visibility", "hidden");
    })
  }
  // draw x-axis labels
  if (axisOrientation == 1){
      var xAxisScale = d3.scaleLinear().domain([xmax, 0]).range([0, gwidth-100])
  }else{
      var xAxisScale = d3.scaleLinear().domain([0, xmax]).range([0, gwidth-100])
  }
  
  var xAxis = d3.axisBottom(xAxisScale)
                  .scale(xAxisScale);
  tg.attr("class", "x axis")
     .call(xAxis);
  
  // draw tree in side panel
  var sideplot = lg.selectAll("lines")
                   .data(data.edges)
                   .enter().append("line")
                   .attr("class", "lines")
                   .attr("x1", function(d) { return xlScale(d.x0); })
                   .attr("x2", function(d) { return xlScale(d.x1); })
                   .attr("y1", function(d) { return ylScale(d.y0); })
                   .attr("y2", function(d) { return ylScale(d.y1); })
                   .attr("stroke-width", 1.0)
                   .attr("stroke", function(d) { return d.colour; });

  //draw the legend, only if legends exist.
  if(coloredGroups !== undefined) { //init the svg tag ONLY if there are legend that exist
     legendsvg = legendDiv.append("svg")
          .attr("width", (width - 110 - 165-220)+"px")
          .attr("height", ((((Object.keys(coloredGroups).length) + 1 )* 20 ) + 10)+"px");
    var count = 1 //number of legend rows already drawn
    for (keys in coloredGroups){
      legendsvg.append("circle")
        .attr("cx",20)
        .attr("cy",(20*count))
        .attr("r", 6)
        .style("fill", coloredGroups[keys][0])
      legendsvg.append("text")
        .attr("x", 28)
        .attr("y", (20*count)+5)
        .text(keys + "(n=" + coloredGroups[keys][1] + ")")
        .style("font-size", "15px")
        .attr("alignment-baseline","middle")
      count++;
    }
  }
}
updateTree() //init basic tree for the first time on page load

//define a set of colors
var totalColors = 0;
var colours = [...defaultColorList]
var coloredGroups = {}

//function called when colorby checkboxes are changed. populates the edge colors
//`chkbox` is the HTML checkbox object passed in as "this" from the onchange() function.
function changeSingleOptionColor(chkbox){
  const target = chkbox.control.id.split("_");
  var idToColor = target.pop();
  var colorBy = target.join("_");
  
  var n = 0 //counter for number of edges with color X
  if (chkbox.children[0].checked == true){ //set a color because box checked
    //if more than 12 colors, just give up being qualitative and use a random color
    if (colours.length == 0){
      var randomColor = Math.floor(Math.random()*16777215).toString(16);
      colours.push( "#" + randomColor);
    }
    //color the edges
    if (idToColor in presetColors){
      colourToUse = presetColors[idToColor];
    }else{
      colourToUse = colours.shift();
    }
    tipOnlyEdgesIndexList.forEach(function(i){
      if (data.edges[i][colorBy] == idToColor){
        data.edges[i].colour = colourToUse;
        n++;
      }
    });
    coloredGroups[idToColor] = [colourToUse,n];
  } else if (chkbox.children[0].checked == false){ //remove a color because box unchecked
      colours.unshift(coloredGroups[idToColor][0])
      delete coloredGroups[idToColor]
      tipOnlyEdgesIndexList.forEach(function(i){
        if (data.edges[i][colorBy] == idToColor){
          data.edges[i].colour = "#D3D3D3";
        }
      });
  }
  updateTree(true);
}


//function called when select all is checked. populates ALL the edge colors
//`d` is the label object passed in as "this" from the onchange() function of the select all checkbox. 
//`colorBy` is the metadata coloumn to check when coloring edges/nodes
//`noCheckBoxControl` is a workaround to utilize the same function to color all edges/nodes on page load. Defaults false
function changeAllOptionColor(d, colorBy, noCheckBoxControl = false){
  colours = [...defaultColorList] //["#A6CEE3", "#1F78B4",  "#33A02C", "#FB9A99", "#E31A1C", "#FDBF6F","#B2DF8A", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99", "#B15928"];
  coloredGroups = {}
  var checkboxes = optionDiv.selectAll("input"); //get all the checkboxes 
  var colourToUse;

  var checked;
  if (noCheckBoxControl){
    checked = true
  }else{
    checked = d.children[0].checked
  }

  if (colours.length == 0){ //generate a new color when we run out.
    var randomColor = Math.floor(Math.random()*16777215).toString(16);
    colours.push( "#" + randomColor);
  }

  if (checked == true){ //color the all the edges.
    checkboxes.property("checked", true);
    tipOnlyEdgesIndexList.forEach(function(i){
      if(data.edges[i].isTip == "TRUE"){
        if (!(data.edges[i][colorBy] in coloredGroups)){//key dont exist, use a new color
            if (colours.length == 0){
              var randomColor = Math.floor(Math.random()*16777215).toString(16);
              colours.push( "#" + randomColor);
            }
            if (data.edges[i][colorBy] in presetColors){
                colourToUse = presetColors[data.edges[i][colorBy]];
            } else{
              colourToUse = colours.shift();
            }            
            data.edges[i].colour = colourToUse;
            coloredGroups[data.edges[i][colorBy]] = [colourToUse, 1]
          }else{
            data.edges[i].colour = coloredGroups[data.edges[i][colorBy]][0];
            coloredGroups[data.edges[i][colorBy]][1] += 1
          }
      }
    });
    } else{ //uncolor all the edges
    checkboxes.property("checked", false);
    tipOnlyEdgesIndexList.forEach(function(i){
      data.edges[i].colour = "#D3D3D3";          
    });
  }

  //sort the legend labels
  coloredGroups = Object.keys(coloredGroups)
  .sort()
  .reduce(function (acc, key) { 
      acc[key] = coloredGroups[key];
      return acc;
  }, {})

  updateTree(true)//render the tree.
}

//function to get all unique values of a metadata column
//`field` the key representing the metadata column in the data json object.
function populateMetadataOptions(field){
  var options = [];
  tipOnlyEdgesIndexList.forEach(function(i){
    options.push(data.edges[i][field]);
  });
  return ([...new Set(options)].sort() );  
}

//function for populating the checkboxes for colorgroups
//`d` is the dropdown object passed in as "this" with the onchange() function.
//`value` is the workaround for default color scheme on page load.
function displayOptions(d, value = ""){
  var target;
  if (value != "") { //default view on page load
    target = value;
  } else{ //select view using dropdown menu.
    target = d.value; 
  }
  coloredGroups = {} 
  totalColors = 0; 
  colours = [...defaultColorList]//["#A6CEE3", "#1F78B4",  "#33A02C", "#FB9A99", "#E31A1C", "#FDBF6F","#B2DF8A", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99", "#B15928"]; //reset the color to use list
	optionDiv.selectAll("*").remove()
	colorByDiv.selectAll("label").remove()

  	var metadataOptions = populateMetadataOptions(target) //get all the unique values within a metadata column
  	var selectAllBox = colorByDiv //insert a select all checkbox
  	          .append("label")
              .html(function(d) {
                    return '<input type="checkbox" id="selectallbox" checked>Select All'; //onchange="changeColor(this)"
                  })
              .on("change", function() { changeAllOptionColor(this, target);}) //onchange event is bound to the label, not checkbox. workaround to keep labels AFTER checkbox.

    var optionDivData = optionDiv.selectAll("input") 
              .data(metadataOptions)
              .enter()
              //.append("span")
              .append("label")
              .html(function(d) {
                  	id = target + "_" + d
                    return '<input type="checkbox" id="' + id+ '" >' + d+ '<br>'; //onchange="changeColor(this)"
                  })
              .on("change", function() { changeSingleOptionColor(this);}) //onchange event is bound to the label, not checkbox. workaround to keep labels AFTER checkbox.

    changeAllOptionColor (this, target, true) //force select all to be checked by default
}


/* #region init */

//intial loop through the data.edges object to create optimization arrays used for faster plot rendering. 
var metadataFields = [] //array of available metadata keys
var tipOnlyEdgesIndexList = [] //array of index of data.edges containing only edges that are tips
for(var i = 0; i < data.edges.length; i++){
  if (data.edges[i].isTip == "TRUE"){
    tipOnlyEdgesIndexList.push(i)
  } else{
    data.edges[i].colour = "#D3D3D3" //set default colors to light grey.
  }
  for (key in data.edges[i]){
    if (!metadataFields.includes(key)) {
      metadataFields.push(key);
    }
  }
}
var fieldsToRemove = ["parent", "child","colour", "length", "isTip","x0", "x1","y0","y1", "fasta_header_name"] //list of keys that are not metadata
var fieldsToNotIncludeInDropdown = ["GID", "isolate"]
//remove the non-metadata keys.
metadataFields = metadataFields.filter( function( el ) {
  return !fieldsToRemove.includes( el );
} ); 
data.tips = tipOnlyEdgesIndexList.map(i => data.edges[i])//defines new tip only edge obj. used to draw the circles.

//move the default color scheme to the beginning of the dropdown menu.
metadataFields = metadataFields.filter(item => item != defaultColorBy);
metadataFields.unshift(defaultColorBy);
sortMetadataFields = metadataFields.filter( function( el ) {
  return !fieldsToNotIncludeInDropdown.includes( el );
} ); 
//draws the dropdown menu.
var colorByDivData = colorByDiv
              .append("select")
                .on("change", function() { displayOptions(this);})
              .selectAll("option")
                .data(sortMetadataFields)
                .enter()
                .append("option")
                  .attr('class','selection')
                  .attr('value', function(d) {
                    return d;
                  })
                  .text(function(d) {
                    return d;
                  })

//force default color scheme
displayOptions (this, defaultColorBy) 
