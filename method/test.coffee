method = require './method'
asValue = method.asValue

describe 'method plugin', ->

	beforeEach ->
		console.log '-----------------------------------------'

	describe 'values', ->
		traits = (value) -> [
			method.asValue(value),
			method.asUnits(value),
			method.hasUnits(value)]

		it 'can be null', ->
			# expect(traits null).to.eql [NaN, [], false]

		it 'can be a number', ->
			expect(traits 100).to.eql [100, [], false]

		it 'can be a string', ->
			expect(traits "200").to.eql [200, [], false]

		it 'can be an array', ->
			expect(traits [300,400,500]).to.eql [300, [], false]

		it 'can be an object', ->
			expect(traits {value: 400}).to.eql [400, [], false]

		it 'can have units', ->
			expect(traits {value: 500, units:['mph']}).to.eql [500, ['mph'], true]

		it 'can have a value with units', ->
			expect(traits {value: {value: 600, units:['ppm']}}).to.eql [600, ['ppm'], true]

		it 'can have empty units', ->
			expect(traits {value: 700, units:[]}).to.eql [700, [], false]

		it 'can be an array with units within', ->
			expect(traits [{value: 800, units:['feet']}, 900]).to.eql [800, ['feet'], true]

	describe 'simplify', ->

		it 'no units', ->
			value = method.simplify {value: 100}
			expect(value).to.be 100

		it 'empty units', ->
			value = method.simplify {value: 200, units: []}
			expect(value).to.be 200

	describe 'parsing', ->

		it 'recognizes numbers', (done) ->
			state =
				item: {text: "123"}
			method.dispatch state, (state) ->
				expect(state.list).to.eql [123]
				done()

		it 'defines values', (done) ->
			state =
				item: {text: "321 abc"}
			method.dispatch state, (state) ->
				expect(state.output.abc).to.be 321
				done()

		it 'retrieves values', (done) ->
			state =
				item: {text: "abc"}
				input: {abc: 456}
			method.dispatch state, (state) ->
				expect(state.list).to.eql [456]
				done()

		it 'computes sums', (done) ->
			state =
				item: {text: "abc\n2000\nSUM\n1000\nSUM xyz"}
				input: {abc: 456}
			method.dispatch state, (state) ->
				expect(state.output.xyz).to.be 3456
				done()

	describe 'errors', ->

		it 'illegal input', (done) ->
			state =
				item: {text: "!!!"}
				caller: {errors: []}
			method.dispatch state, (state) ->
				expect(state.caller.errors[0].message).to.be "can't parse '!!!'"
				done()

		it 'undefined variable', (done) ->
			state =
				item: {text: "foo"}
				caller: {errors: []}
			method.dispatch state, (state) ->
				expect(state.caller.errors[0].message).to.be "can't find value of 'foo'"
				done()

		it 'undefined function', (done) ->
			state =
				item: {text: "RUMBA"}
				caller: {errors: []}
			method.dispatch state, (state) ->
				expect(state.caller.errors[0].message).to.be "don't know how to 'RUMBA'"
				done()

		it 'precomputed checks', (done) ->
			state =
				item: {text: "2\n3\nSUM five", checks: {five: 6}}
				caller: {errors: []}

			method.dispatch state, (state) ->
				expect(state.caller.errors[0].message).to.be "five != 6.0000"
				done()

	describe 'unit parsing', ->

		it 'sorts words', ->
			units = method.parseUnits "Pound Foot"
			expect(units).to.eql ["foot", "pound"]

		it 'ignores extra spaces', ->
			units = method.parseUnits "  Pound    Foot   "
			expect(units).to.eql ["foot", "pound"]

		it 'ignores non-word characters', ->
			units = method.parseUnits "$ & ¢"
			expect(units).to.eql []

		it 'expands squares and cubes', ->
			units = method.parseUnits "Square Pound Cubic Foot"
			expect(units).to.eql ["foot", "foot", "foot", "pound", "pound"]

		it 'recognizes ratios', ->
			units = method.parseRatio "(Pounds / Square Foot)"
			expect(units).to.eql {numerator: ["pounds"], denominator: ["foot", "foot"]}

		it 'recognizes non-ratios', ->
			units = method.parseRatio "(Foot Pound)"
			expect(units).to.eql ["foot", "pound"]

		it 'recognizes inversions', ->
			units = method.parseRatio "( / Seconds)"
			expect(units).to.eql {numerator: [], denominator: ["seconds"]}

		it 'ignores text outside parens', ->
			units = method.parseLabel "Speed (MPH) Moving Average"
			expect(units).to.eql {units: ["mph"]}

		it 'recognizes conversions as unit pairs', ->
			units = method.parseLabel "1.47	(Feet / Seconds) from (Miles / Hours) "
			expect(units).to.eql
				units: { numerator: [ 'feet' ], denominator: [ 'seconds' ] }
				from: { numerator: [ 'miles' ], denominator: [ 'hours' ] }

		it 'defines values as objects', (done) ->
			state =
				item: {text: "321 abc (mph)"}
			method.dispatch state, (state) ->
				expect(state.output['abc (mph)']).to.eql {value: 321, units: ["mph"]}
				done()

		it 'defines conversion constants as objects', (done) ->
			state =
				item: {text: "1.47 (Feet/Seconds) from (Miles/Hours)"}
			method.dispatch state, (state) ->
				expect(state.output['(Feet/Seconds) from (Miles/Hours)']).to.eql
					value: 1.47
					units:
						numerator:['feet']
						denominator:['seconds']
					from:
						numerator:['miles']
						denominator:['hours']
				done()

	describe 'conversions', ->

		input =
			"(fps) from (mph)":
				value: 88 / 60
				units: ['fps']
				from: ['mph']
			"speed":
				value: 30
				units: ['mph']

		it 'apply to arguments', (done) ->
			state =
				input: input
				item: {text: "30 (mph)\n44 (fps)\nSUM speed"}
			method.dispatch state, (state) ->
				expect(state.output['speed']).to.eql
					value: 88
					units: ['fps']
				done()

		it 'apply to variables', (done) ->
			state =
				input: input
				item: {text: "speed\n44 (fps)\nSUM speed"}
			method.dispatch state, (state) ->
				expect(state.output['speed']).to.eql
					value: 88
					units: ['fps']
				done()

		it 'apply to results', (done) ->
			state =
				input: input
				item: {text: "60 (mph)\nSUM (fps)"}
			method.dispatch state, (state) ->
				expect(state.output['(fps)']).to.eql
					value: 88
					units: ['fps']
				done()

		it 'selected from alternatives', (done) ->
			alternatives =
			"speeding":
				value: 120
				units: ['mph']
			"(fps) from (mph)":
				value: 88 / 60
				units: ['fps']
				from: ['mph']
			"(miles/hour) from (mph)":
				value: 1
				units: {numerator: ['miles'], denominator: ['hour']}
				from: ['mph']
			"speed":
				value: 88
				units: ['fps']
			state =
				input: alternatives
				item: {text: "speeding\nSUM (fps)"}
			method.dispatch state, (state) ->
				expect(state.output['(fps)']).to.eql
					value: 88*2
					units: ['fps']
				done()

		it 'optional when units are acceptable', (done) ->
			state =
				input: input
				item: {text: "60 (mph)\n30 (mph)\nSUM"}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql
					value: 90
					units: ['mph']
				done()

		it 'reported when missing', (done) ->
			state =
				item: {text: "22 (fps)\n15 (mps)\nSUM"}
				caller: {errors: []}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql
					value: 22
					units: ['fps']
				expect(state.caller.errors[0].message).to.be "can't convert to [mps] from [fps]"
				done()

		it 'adds units to SHOW legend', (done) ->
			state =
				item: {text: "36 (in/yd)\nSHOW Mumble"}
			method.dispatch state, (state) ->
				expect(state.show[0]).to.eql
					legend: "Mumble<br>( in / yd )"
					readout: "36"
				done()

	describe 'products', ->

		input =
			"(Feet/Seconds) per (Miles/Hours)":
				value: 88 / 60
				units: ['fps']
				from: ['mph']
			"side":
				value: 6
				units: ['Inches']

		it 'repeats units', (done) ->
			state =
				input: input
				item: {text: "side\nside\nPRODUCT area"}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql
					value: 36
					units: ['Inches', 'Inches']
				done()

		it 'cancels units', (done) ->
			state =
				input: input
				item: {text: "2 (yd)\n3 (ft/yd)\n12 (in/ft)\nPRODUCT height"}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql
					value: 72
					units: ['in']
				done()

		it 'invert units for ratio', (done) ->
			state =
				input: input
				item: {text: "72 (in)\n2 (yd)\nRATIO"}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql
					value: 36
					units: {numerator: ['in'], denominator: ['yd']}
				done()

	describe 'expressions', ->

		it 'can be lexed with literals', ->
			tokens = method.lexer '12+(345-678)*910'
			expect(tokens).to.eql [12, '+', '(', 345, '-', 678, ')', '*', 910]

		it 'can be lexed with variables', ->
			syms = {alpha: 100, beta: 200}
			tokens = method.lexer '12+(alpha-678)*beta', syms
			expect(tokens).to.eql [12, '+', '(', 100, '-', 678, ')', '*', 200]

		it 'can be constant', ->
			value = method.parser [12]
			expect(value).to.be 12

		it 'do multiply first', ->
			value = method.parser [2, '+', 3, '*', 5]
			expect(value).to.be 17

		it 'do parens first', ->
			value = method.parser ['(', 2, '+', 3, ')', '*', 5]
			expect(value).to.be 25

		it 'applied by CALC', (done) ->
			state =
				item: {text: "CALC 12+(345-678)*910"}
			method.dispatch state, (state) ->
				expect(state.list[0]).to.be -303018
				done()

		it 'applied by CALC with variables', (done) ->
			state =
				output: {"Hourly Rate": 16.45, "Regular Hours": 40, "Overtime Hours": 12}
				item: {text: "CALC Rate * ( Regular + 1.5 * Overtime )"}
			console.log 'state', state
			method.dispatch state, (state) ->
				expect(Math.round(state.list[0])).to.eql 954
				done()

		it 'applied by CALC with variables and units', (done) ->
			state =
				item: {text: "20.00 Rate (dollar / hour)\n40 Regular (hour)\n12 Overtime (hour)\nCALC Rate * ( Regular + 1.5 * Overtime )"}
			console.log 'state', state
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql {value: 1160.00, units: ['dollar']}
				done()

		it 'applied by CALC with all operators, variables and units', (done) ->
			state =
				item: {text: "10 w (in)\n30 h (in)\n15 t (s)\nCALC t*(h/t + w/t - (h+w)/t)"}
			console.log 'state', state
			method.dispatch state, (state) ->
				expect(state.list[0]).to.eql {value: 0, units: ['in']}
				done()
