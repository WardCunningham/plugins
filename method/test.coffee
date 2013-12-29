method = require './method'

describe 'method plugin', ->

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
				console.log state
				expect(state.output['(Feet/Seconds) from (Miles/Hours)']).to.eql
					value: 1.47
					units:
						numerator:['feet']
						denominator:['seconds']
					from:
						numerator:['miles']
						denominator:['hours']
				done()


