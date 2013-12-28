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
