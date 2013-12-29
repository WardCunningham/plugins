asValue = (obj) ->
  return NaN unless obj?
  switch obj.constructor
    when Number then obj
    when String then +obj
    when Array then asValue(obj[0])
    when Object then asValue(obj.value)
    when Function then asValue obj()
    else NaN

asUnits = (obj) ->
  return [] unless obj?
  switch obj.constructor
    when Number then []
    when String then []
    when Array then units(obj[0])
    when Object then obj.units || units(obj.value)
    when Function then units(obj())
    else []

parseUnits = (string) ->
  string = string.toLowerCase()
  string = string.replace /\bsquare\s+(\w+)\b/, "$1 $1"
  string = string.replace /\bcubic\s+(\w+)\b/, "$1 $1 $1"
  units = string.match /(\w+)/g
  return [] unless units?
  units.sort()

parseRatio = (string) ->
  if ratio = string.match /^\((.+?)\/(.+?)\)$/
    {numerator: parseUnits(ratio[1]), denominator: parseUnits(ratio[2])}
  else if units = string.match /^\((.+?)\)$/
    parseUnits units[1]
  else undefined

parseLabel = (string) ->
  if phrases = string.match(/(\(.+?\)).*?(\(.+?\))?[^(]*$/)
    result = {}
    result.units = parseRatio phrases[1]
    result.from = parseRatio phrases[2] if phrases[2]
  result

extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

sum = (v) ->
  v.reduce (s,n) -> s += n

avg = (v) ->
  sum(v)/v.length

round = (n) ->
  return '?' unless n?
  if n.toString().match /\.\d\d\d/
    n.toFixed 2
  else
    n

annotate = (text) ->
  return '' unless text?
  " <span title=\"#{text}\">*</span>"

print = (report, value, hover, line, comment, color) ->
  return unless report?
  long = ''
  if line.length > 40
    long = line
    line = "#{line.substr 0, 20} ... #{line.substr -15}"
  report.push """
    <tr style="background:#{color};">
      <td style="width: 20%; text-align: right; padding: 0 4px;" title="#{hover||''}">
        <b>#{round value}</b>
      <td title="#{long}">#{line}#{annotate comment}</td>
    """

dispatch = (state, done) ->
  state.list ||= []
  state.input ||= {}
  state.output ||= {}
  state.lines ||= state.item.text.split "\n"
  line = state.lines.shift()
  return done state unless line?

  attach = (search) ->
    for elem in wiki.getDataNodes state.div
      if (source = $(elem).data('item')).text.indexOf(search) >= 0
        return source.data
    throw new Error "can't find dataset with caption #{search}"

  lookup = (v) ->
    table = attach 'Tier3ExposurePercentages'
    return NaN if isNaN v[0]
    return NaN if isNaN v[1]
    row = _.find table, (row) ->
      asValue(row.Exposure)==v[0] and asValue(row.Raw)==v[1]
    throw new Error "can't find exposure #{v[0]} and raw #{v[1]}" unless row?
    asValue(row.Percentage)

  polynomial = (v, subtype) ->
    table = attach 'Tier3Polynomials'
    row = _.find table, (row) ->
      "#{row.SubType} Scaled" == subtype and asValue(row.Min) <= v and asValue(row.Max) > v
    throw new Error "can't find applicable polynomial for #{v} in '#{subtype}'" unless row?
    result  = asValue(row.C0)
    result += asValue(row.C1) * v
    result += asValue(row.C2) * Math.pow(v,2)
    result += asValue(row.C3) * Math.pow(v,3)
    result += asValue(row.C4) * Math.pow(v,4)
    result += asValue(row.C5) * Math.pow(v,5)
    result += asValue(row.C6) * Math.pow(v,6)
    result = 1 - result if asValue(row['One minus'])
    Math.min(1, Math.max(0, result))

  show = (list, legend) ->
    value = sum list
    readout = Number(value).toLocaleString('en')
    state.show ||= []
    state.show.push {readout, legend}
    value

  apply = (name, list, label) ->
    switch name
      when 'SUM' then sum list
      when 'AVG', 'AVERAGE' then avg list
      when 'MIN', 'MINIMUM' then _.min list
      when 'MAX', 'MAXIMUM' then _.max list
      when 'RATIO' then list[0] / list[1]
      when 'ACCUMULATE' then (sum list) + (output[label] or input[label] or 0)
      when 'FIRST' then list[0]
      when 'PRODUCT' then list.reduce (p,n) -> p *= n
      when 'LOOKUP' then lookup list
      when 'POLYNOMIAL' then polynomial list[0], label
      when 'SHOW' then show list, label
      else throw new Error "don't know how to '#{name}'"

  color = '#eee'
  value = comment = hover = null
  input = state.input
  output = state.output
  list = state.list

  try
    if args = line.match /^([0-9.eE-]+) +([\w \/%(){},&-]+)$/
      result = +args[1]
      units = parseLabel line = args[2]
      result = extend {value: result}, units if units
      output[line] = value = result
    else if args = line.match /^([A-Z]+) +([\w \/%(){},&-]+)$/
      [value, list, count] = [apply(args[1], list, args[2]), [], list.length]
      color = '#ddd'
      hover = "#{args[1]} of #{count} numbers\n= #{value}"
      line = args[2]
      if (output[line]? or input[line]?) and !state.item.silent
        previous = asValue(output[line]||input[line])
        if Math.abs(change = value/previous-1) > 0.0001
          comment = "previously #{previous}\nΔ #{round(change*100)}%"
      output[line] = value
      if (s = state.item.checks) && (v = s[line]) != undefined
        if asValue(v).toFixed(4) != value.toFixed(4)
          color = '#faa'
          line += " != #{asValue(v).toFixed(4)}"
          state.caller.errors.push({message: line}) if state.caller
    else if args = line.match /^([A-Z]+)$/
      [value, list, count] = [apply(args[1], list), [], list.length]
      color = '#ddd'
      hover = "#{args[1]} of #{count} numbers\n= #{value}"
    else if line.match /^[0-9\.eE-]+$/
      value = +line
      line = ''
    else if args = line.match /^ *([\w \/%(){},&-]+)$/
      if output[args[1]]?
        value = output[args[1]]
      else if input[args[1]]?
        value = asValue(input[args[1]])
      else
        color = '#edd'
        comment = "can't find value of '#{line}'"
    else
      color = '#edd'
      comment = "can't parse '#{line}'"
  catch err
    color = '#edd'
    value = null
    comment = err.message

  if state.caller? and color == '#edd'
    state.caller.errors.push({message: comment})
  state.list = list
  state.list.push +value if value? and ! isNaN +value
  print state.report, value, hover, line, comment, color
  dispatch state, done

bind = (div, item) ->
emit = (div, item, done) ->

  input = {}
  output = {}

  candidates = $(".item:lt(#{$('.item').index(div)})")
  for elem in candidates
    elem = $(elem)
    if elem.hasClass 'radar-source'
      _.extend input, elem.get(0).radarData()
    else if elem.hasClass 'data'
      _.extend input, elem.data('item').data[0]

  div.addClass 'radar-source'
  div.get(0).radarData = -> output

  div.mousemove (e) ->
    if $(e.target).is('td')
      $(div).triggerHandler('thumb', $(e.target).text())
  div.dblclick (e) ->
    if e.shiftKey
      wiki.dialog "JSON for Method plugin",  $('<pre/>').text(JSON.stringify(item, null, 2))
    else
      wiki.textEditor state.div, state.item

  state = {div: div, item: item, input: input, output: output, report:[]}
  dispatch state, (state, output) ->
    if state.show
      state.div.append $show = $ "<div class=data>"
      for each in state.show
        $show.append $ """
          <p class=readout>#{each.readout}</p>
          <p class=legend>#{each.legend}</p>
        """
    else
      text = state.report.join "\n"
      table = $('<table style="width:100%; background:#eee; padding:.8em; margin-bottom:5px;"/>').html text
      state.div.append table
    setTimeout done, 10  # slower is better for firefox

evaluate = (caller, item, input, done) ->
  state = {caller: caller, item: item, input: input, output: {}}
  dispatch state, (state, input) ->
    done state.caller, state.output

window.plugins.method = {emit, bind, eval:evaluate} if window?
module.exports = {dispatch, parseUnits, parseRatio, parseLabel} if module?

