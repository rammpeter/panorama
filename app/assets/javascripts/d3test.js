// Test for D3, currently not used

d3test = function(canvas_id){
    const width = $(window).width();
    const height = $('#'+canvas_id).height();
    $('#'+canvas_id).width(width);                             // full width

    var data = [
        { date: "2021-05-20", CPU: 22.7, IO: 15.2},
        { date: "2021-06-20", CPU: 11.7, IO: 7.2},
        { date: "2021-07-20", CPU: 23.7, IO: 4.3},
        { date: "2021-08-20", CPU: 14.7, IO: 0.9},
        { date: "2021-09-20", CPU: 22.7, IO: 8.7}
    ];

    var series = d3.stack().keys(['CPU', 'IO'])(data);

    const margin = {top: 20, right: 30, bottom: 30, left: 40};

    const area = d3.area()
        .x(d => x(d.data.date))
        .y0(d => y(d[0]))
        .y1(d => y(d[1]));

    var color = d3.scaleOrdinal()
        .domain(['CPU', 'IO'])
        .range(d3.schemeCategory10);

    const x = d3.scaleUtc()
        .domain(d3.extent(data, d => d.date))
        .range([margin.left, width - margin.right]);

    const y = d3.scaleLinear()
        .domain([0, d3.max(series, d => d3.max(d, d => d[1]))]).nice()
        .range([height - margin.bottom, margin.top]);

    var wait_class_d3 = d3.select('#wait_class_canvas');


    wait_class_d3.append("g")
        .selectAll("path")
        .data(series)
        .join("path")
        .attr("fill", ({key}) => color(key))
        .attr("d", area)
        .append("title")
        .text(({key}) => key);

    wait_class_d3.append("g")
        .attr("transform", `translate(0,${height - margin.bottom})`)
        .call(d3.axisBottom(x).ticks(width / 80).tickSizeOuter(0));


    wait_class_d3.append("g")
        .attr("transform", `translate(${margin.left},0)`)
        .call(d3.axisLeft(y))
        .call(g => g.select(".domain").remove())
        .call(g => g.select(".tick:last-of-type text").clone()
            .attr("x", 3)
            .attr("text-anchor", "start")
            .attr("font-weight", "bold")
            .text(data.y));

    wait_class_d3.append("circle")
        .attr("cx", 2).attr("cy", 2).attr("r", 40).style("fill", "blue");
    wait_class_d3.append("circle")
        .attr("cx", 140).attr("cy", 70).attr("r", 40).style("fill", "red");
    wait_class_d3.append("circle")
        .attr("cx", 300).attr("cy", 100).attr("r", 40).style("fill", "green");

}