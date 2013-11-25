code = []

compile = (text) ->
	code = []
	for line in text.split(/\n/)
		code.push line.split(/\s+/)

pretty = (words) ->
	"<b>#{words[0]}</b> #{words[1..99].join ' '}"

mark = (state) ->
	state.$drawing.append """
		<div style="
			width: 5px;
			height: 5px;
			background-color: red;
			position: absolute;
			left: #{7*state.x}px;
			top: #{7*state.y}px;
			-webkit-transform: rotate( #{-state.t}deg );
		" />
	"""
	state

go = (state) ->
	radians = state.t * Math.PI / 180
	state.x = state.x + Math.sin radians
	state.y = state.y + Math.cos radians
	mark state

left = (state) ->
	state.t = state.t + 15
	state

right = (state) ->
	state.t = state.t - 15
	state

fetch = (word) ->
	choices = code.filter (each) -> each[0] == word
	if choices.length
		choices[Math.floor(choices.length*Math.random())]
	else
		[word]

fork = (words, state) ->
	setTimeout (-> apply words, copy state), 250
	state

copy = (obj) ->
	$.extend {}, obj

apply = (words, state) ->
	console.log 'apply', words, state
	for word in words[1..99]
		state = switch word
			when 'go' then go state
			when 'left' then left state
			when 'right' then right state
			else fork fetch(word), state

emit = ($item, item) ->
	compile item.text
	$item.append """
		<div class="drawing" style="position:relative;"/>
	  <p style="background-color:#eee;padding:15px;">
	    #{(pretty line for line in code).join '<br>'}
	  </p>
	"""
	apply code[0], {x:0, y:0, t:45, $drawing:$item.find('.drawing')}

bind = ($item, item) ->
  $item.dblclick -> wiki.textEditor $item, item

window.plugins.mumblefoo = {emit, bind}
