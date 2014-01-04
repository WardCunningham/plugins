

############ units ############

conversions = null

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
    when Array then asUnits(obj[0])
    when Object
      if obj.units? then obj.units
      else if obj.value? then asUnits obj.value
      else []
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

emptyArray = (obj) ->
  obj.constructor is Array and obj.length is 0

simplify = (obj) ->
  return NaN unless obj?
  switch obj.constructor
    when Number then obj
    when String then +obj
    when Array then simplify(obj[0])
    when Object
      if obj.units == undefined then simplify obj.value
      else if emptyArray obj.units then simplify obj.value
      else obj
    when Function then simplify obj()
    else NaN

inspect = (obj) ->
  return "nullish" unless obj?
  switch obj.constructor
    when Number then obj
    when String then obj
    when Array then JSON.stringify(obj).replace /\"/g, ''
    when Object then JSON.stringify(obj).replace /\"/g, ''
    when Function then 'functionish'
    else "wierdish"

findFactor = (to, from) ->
  for label, value of conversions
    if value.from? and isEqual from, value.from
      if isEqual to, value.units
        return asValue value
    if value.from? and isEqual to, value.from
      if isEqual from, value.units
        return 1/(asValue value)
  return null

hasUnits = (obj) ->
  not emptyArray asUnits obj

isEqual = (a, b) ->
  (inspect a) is (inspect b)

coerce = (toUnits, value) ->
  # console.log "coerce to #{inspect toUnits}"
  if isEqual toUnits, fromUnits = asUnits simplify value
    value
  else if factor = findFactor toUnits, fromUnits
    return {value: factor * asValue(value), units: toUnits}
  else
    throw new Error "can't convert to #{inspect toUnits} from #{inspect fromUnits}"

unpackUnits = (value) ->
  v = asValue value
  u = asUnits value
  if u.constructor is Array
    numerator = u
    denominator = []
  else
    numerator = u.numerator
    denominator = u.denominator
  [v, numerator, denominator]

packUnits = (nums, denoms) ->
  n = [].concat nums...
  d = [].concat denoms...
  keep = []
  for unit in d
    if (where = n.indexOf unit) is -1
      keep.push unit
    else
      n.splice where, 1
  if keep.length
    {numerator: n.sort(), denominator: keep.sort()}
  else
    n.sort()

printUnits = (units) ->
  if emptyArray units
    ''
  else if units.constructor is Array
    "( #{units.join ' '} )"
  else
    "( #{units.numerator.join ' '} / #{units.denominator.join ' '} )"


############ calculation ############

sum = (v) ->
  simplify v.reduce (sum, each) ->
    toUnits = asUnits simplify each
    value = coerce toUnits, sum
    {value: asValue(value) + asValue(each), units: toUnits }

product = (v) ->
  simplify v.reduce (prod, each) ->
    [p, pn, pd] = unpackUnits prod
    [e, en, ed] = unpackUnits each
    {value: p*e, units: packUnits([pn,en],[pd,ed])}

ratio = (v) ->
  # list[0] / list[1]
  [n, nn, nd] = unpackUnits v[0]
  [d, dn, dd] = unpackUnits v[1]
  simplify {value: n/d, units: packUnits([nn,dd],[nd,dn])}

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
        <b>#{round asValue value}</b>
      <td title="#{long}">#{line}#{annotate comment}</td>
    """

############ expression ############

ident = (str, syms) ->
  if str.match /^\d+(\.\d+)?(e\d+)?$/
    Number str
  else
    regexp = new RegExp "\\b#{str}\\b"
    for label, value of syms
      console.log "does '#{label}' match '#{str}'"
      return value if label.match regexp
    throw new Error "can't find value for '#{str}'"

lexer = (str, syms={}) ->
  buf = []
  tmp = ""
  i = 0
  while i < str.length
    c = str[i++]
    continue  if c is " "
    if c is "+" or c is "-" or c is "*" or c is "/" or c is "(" or c is ")"
      if tmp
        buf.push ident(tmp, syms)
        tmp = ""
      buf.push c
      continue
    tmp += c
  buf.push ident(tmp, syms) if tmp
  buf

parser = (lexed) ->
  # term : fact { (*|/) fact }
  # fact : number | '(' expr ')'
  fact = ->
    c = lexed.shift()
    return c  if typeof (c) is "number"
    if c is "("
      c = expr()
      throw new Error "missing paren"  if lexed.shift() isnt ")"
      return c
    throw new Error "missing number"
  term = ->
    c = fact()
    while lexed[0] is "*" or lexed[0] is "/"
      o = lexed.shift()
      c = c * term()  if o is "*"
      c = c / term()  if o is "/"
    c
  expr = ->
    c = term()
    while lexed[0] is "+" or lexed[0] is "-"
      o = lexed.shift()
      c = c + term()  if o is "+"
      c = c - term()  if o is "-"
    c
  expr()

############ interpreter ############

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
    legend += "<br>#{printUnits asUnits value}" if emptyArray(asUnits parseLabel legend)
    readout = Number(asValue value).toLocaleString('en')
    state.show ||= []
    state.show.push {readout, legend}
    value

  apply = (name, list, label='') ->
    result = switch name
      when 'SUM' then sum list
      when 'AVG', 'AVERAGE' then avg list
      when 'MIN', 'MINIMUM' then _.min list
      when 'MAX', 'MAXIMUM' then _.max list
      when 'RATIO' then ratio list
      when 'ACCUMULATE' then (sum list) + (output[label] or input[label] or 0)
      when 'FIRST' then list[0]
      when 'PRODUCT' then product list
      when 'LOOKUP' then lookup list
      when 'POLYNOMIAL' then polynomial list[0], label
      when 'SHOW' then show list, label
      when 'CALC' then parser lexer(label, state.output)
      else throw new Error "don't know how to '#{name}'"
    if name is 'CALC' or emptyArray toUnits = asUnits parseLabel label
      result
    else
      coerce toUnits, result

  color = '#eee'
  value = comment = hover = null
  conversions = input = state.input
  output = state.output
  list = state.list
  label = null

  try
    if args = line.match /^([0-9.eE-]+) +([\w \.%(){},&\*\/+-]+)$/
      result = +args[1]
      units = parseLabel label = args[2]
      result = extend {value: result}, units if units
      output[label] = value = result
    else if args = line.match /^([A-Z]+) +([\w \.%(){},&\*\/+-]+)$/
      [value, list, count] = [apply(args[1], list, args[2]), [], list.length]
      color = '#ddd'
      hover = "#{args[1]} of #{count} numbers\n= #{asValue value} #{printUnits asUnits value}"
      label = args[2]
      if (output[label]? or input[label]?) and !state.item.silent
        previous = asValue(output[label]||input[label])
        if Math.abs(change = value/previous-1) > 0.0001
          comment = "previously #{previous}\nΔ #{round(change*100)}%"
      output[label] = value
      if (s = state.item.checks) && (v = s[label]) != undefined
        if asValue(v).toFixed(4) != asValue(value).toFixed(4)
          color = '#faa'
          label += " != #{asValue(v).toFixed(4)}"
          state.caller.errors.push({message: label}) if state.caller
    else if args = line.match /^([A-Z]+)$/
      [value, list, count] = [apply(args[1], list), [], list.length]
      color = '#ddd'
      hover = "#{args[1]} of #{count} numbers\n= #{asValue value} #{printUnits asUnits value}"
    else if line.match /^[0-9\.eE-]+$/
      value = +line
      label = ''
    else if args = line.match /^ *([\w \.%(){},&\*\/+-]+)$/
      if output[args[1]]?
        value = output[args[1]]
      else if input[args[1]]?
        value = input[args[1]]
      else
        color = '#edd'
        comment = "can't find value of '#{line}'"
    else
      color = '#edd'
      comment = "can't parse '#{line}'"
  catch err
    color = '#edd'
    value = null
    # console.log "trouble", inspect statck
    comment = err.message
  if state.caller? and color == '#edd'
    state.caller.errors.push({message: comment})
  state.list = list
  state.list.push value if value? and ! isNaN asValue value
  console.log "#{line} => #{inspect state.list} #{comment||''}"
  print state.report, value, hover, label||line, comment, color
  dispatch state, done


############ interface ############

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
  dispatch state, (state) ->
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
      if input['debug']
        for label, value of state.output
          state.div.append $("<p class=error>#{label} =><br> #{inspect value}</p>")
      if output['debug']
        for label, value of state.input
          state.div.append $("<p class=error>#{label} =><br> #{inspect value}</p>")
    setTimeout done, 10  # slower is better for firefox

evaluate = (caller, item, input, done) ->
  state = {caller: caller, item: item, input: input, output: {}}
  dispatch state, (state, input) ->
    done state.caller, state.output

window.plugins.method = {emit, bind, eval:evaluate} if window?
module.exports = {lexer, parser, dispatch, asValue, asUnits, hasUnits, simplify, parseUnits, parseRatio, parseLabel} if module?

